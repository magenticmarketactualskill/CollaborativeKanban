# frozen_string_literal: true

module CardIntelligence
  class TypeInferrer
    INFERENCE_PROMPT = <<~PROMPT
      Analyze the following card title and description to determine the most appropriate card type.

      Available card types and their purposes:
      %{type_descriptions}

      Card Information:
      Title: %{title}
      Description: %{description}

      You MUST respond with valid JSON matching this schema:
      {
        "card_type": string (required, lowercase with underscores only, e.g. "task", "bug", "checklist"),
        "confidence": string (optional, one of: "high", "medium", "low"),
        "reasoning": string (optional, max 500 chars, brief explanation)
      }

      Respond ONLY with valid JSON. No markdown, no code blocks, no explanation.
    PROMPT

    def initialize
      @registry = CardSchemas::Registry.instance
    end

    def infer(title:, description: nil)
      # First, try keyword matching (fast, no LLM needed)
      keyword_match = infer_from_keywords(title, description)
      return Result.new(type: keyword_match, confidence: :high, method: :keywords) if keyword_match

      # Check if LLM is enabled
      unless Rails.application.config.llm.enabled
        return Result.new(type: @registry.default_type, confidence: :low, method: :disabled)
      end

      # Fall back to LLM inference
      infer_with_llm(title, description)
    end

    def infer_async(card)
      CardTypeInferenceJob.perform_later(card.id)
    end

    private

    def infer_from_keywords(title, description)
      text = "#{title} #{description}".downcase

      @registry.all.each do |type, schema|
        keywords = schema.keywords
        next if keywords.empty?

        # Strong match: keyword in title
        if keywords.any? { |kw| title.downcase.include?(kw.downcase) }
          return type
        end

        # Moderate match: multiple keywords in combined text
        match_count = keywords.count { |kw| text.include?(kw.downcase) }
        return type if match_count >= 2
      end

      nil
    end

    def infer_with_llm(title, description)
      prompt = format(
        INFERENCE_PROMPT,
        type_descriptions: type_descriptions,
        title: title,
        description: description || "(no description)"
      )

      response = Llm::Router.route(:type_inference, prompt)

      if response.success?
        parse_inference_response(response)
      else
        Result.new(type: @registry.default_type, confidence: :low, method: :fallback, error: response.error)
      end
    end

    def parse_inference_response(response)
      validation = response.validated_json(:type_inference)

      if validation.valid?
        json = validation.data
        inferred_type = json["card_type"]
        confidence = json["confidence"]&.to_sym || :medium

        if @registry.valid_type?(inferred_type)
          Result.new(type: inferred_type, confidence: confidence, method: :llm, provider: response.provider)
        else
          Result.new(type: @registry.default_type, confidence: :low, method: :fallback)
        end
      else
        # Fall back to raw text parsing for backwards compatibility
        inferred_type = response.content.strip.downcase.gsub(/[^a-z_]/, "")
        if @registry.valid_type?(inferred_type)
          Result.new(type: inferred_type, confidence: :medium, method: :llm, provider: response.provider)
        else
          Result.new(type: @registry.default_type, confidence: :low, method: :fallback)
        end
      end
    end

    def type_descriptions
      @registry.all.map do |type, schema|
        keywords_sample = schema.keywords.first(3).join(", ")
        "- #{type}: #{schema.display_name} (keywords: #{keywords_sample})"
      end.join("\n")
    end

    class Result
      attr_reader :type, :confidence, :method, :provider, :error

      def initialize(type:, confidence:, method:, provider: nil, error: nil)
        @type = type
        @confidence = confidence  # :high, :medium, :low
        @method = method          # :keywords, :llm, :fallback, :disabled
        @provider = provider
        @error = error
      end

      def success?
        error.nil?
      end

      def high_confidence?
        confidence == :high
      end
    end
  end
end
