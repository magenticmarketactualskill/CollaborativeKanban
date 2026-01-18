# frozen_string_literal: true

class TypeInferenceTask < ApplicationTask
  def stage_klass_sequence
    [
      ValidateInput,
      KeywordMatch,
      LlmInfer,
      UpdateCard,
      Broadcast
    ]
  end

  # Use conditional execution to skip LlmInfer if KeywordMatch succeeds
  def determine_next_stage(result, current_index)
    stage_klass = stage_klass_sequence[current_index]

    # If KeywordMatch found a type, skip LlmInfer and go to UpdateCard
    if stage_klass == KeywordMatch && result[:type].present?
      stage_klass_sequence.index(UpdateCard)
    else
      super
    end
  end

  # Stage 1: Validate input and find card
  class ValidateInput < TaskFrame::Stage
    include FindsCard

    def perform_work
      result = find_card
      return result if result.failure?

      card = result.value![:card]

      # Skip if already inferred with high confidence
      if card.type_inference_confidence == "high"
        Failure(
          error: "Already inferred with high confidence",
          skipped: true,
          card_id: card.id,
          stage: name
        )
      else
        Success(card: card, title: card.title, description: card.description)
      end
    end
  end

  # Stage 2: Try keyword-based inference (fast, no LLM)
  class KeywordMatch < TaskFrame::Stage
    def perform_work
      prev = task.result_for(ValidateInput)
      title = prev[:title]
      description = prev[:description]
      text = "#{title} #{description}".downcase

      registry = CardSchemas::Registry.instance

      registry.all.each do |type, schema|
        keywords = schema.keywords
        next if keywords.empty?

        # Strong match: keyword in title
        if keywords.any? { |kw| title.downcase.include?(kw.downcase) }
          return Success(
            type: type,
            confidence: :high,
            method: :keywords,
            stage: name
          )
        end

        # Moderate match: multiple keywords in combined text
        match_count = keywords.count { |kw| text.include?(kw.downcase) }
        if match_count >= 2
          return Success(
            type: type,
            confidence: :high,
            method: :keywords,
            stage: name
          )
        end
      end

      # No keyword match found - proceed to LLM
      Success(type: nil, confidence: nil, method: nil, stage: name)
    end
  end

  # Stage 3: LLM-based inference (fallback)
  class LlmInfer < TaskFrame::Stage
    INFERENCE_PROMPT = <<~PROMPT
      Analyze the following card title and description to determine the most appropriate card type.

      Available card types and their purposes:
      %{type_descriptions}

      Card Information:
      Title: %{title}
      Description: %{description}

      Respond with a JSON object containing:
      - card_type: the type name (e.g., "task", "bug", "checklist", "milestone")
      - confidence: your confidence level ("high", "medium", or "low")
      - reasoning: brief explanation (optional)

      Respond ONLY with valid JSON, no additional text.
    PROMPT

    def preconditions_met?
      Rails.application.config.llm.enabled
    end

    def perform_work
      validate_input = task.result_for(ValidateInput)
      title = validate_input[:title]
      description = validate_input[:description]

      registry = CardSchemas::Registry.instance

      prompt = format(
        INFERENCE_PROMPT,
        type_descriptions: type_descriptions(registry),
        title: title,
        description: description || "(no description)"
      )

      response = Llm::Router.route(:type_inference, prompt)

      if response.success?
        validation = response.validated_json(:type_inference)

        if validation.valid?
          json = validation.data
          inferred_type = json["card_type"]&.strip&.downcase&.gsub(/[^a-z_]/, "")

          if registry.valid_type?(inferred_type)
            Success(
              type: inferred_type,
              confidence: json["confidence"]&.to_sym || :medium,
              method: :llm,
              provider: response.provider,
              stage: name
            )
          else
            Success(
              type: registry.default_type,
              confidence: :low,
              method: :fallback,
              stage: name
            )
          end
        else
          # Fallback: try to extract type from raw content
          inferred_type = response.content.strip.downcase.gsub(/[^a-z_]/, "")
          if registry.valid_type?(inferred_type)
            Success(
              type: inferred_type,
              confidence: :low,
              method: :llm,
              provider: response.provider,
              fallback: true,
              stage: name
            )
          else
            Success(
              type: registry.default_type,
              confidence: :low,
              method: :fallback,
              stage: name
            )
          end
        end
      else
        Success(
          type: registry.default_type,
          confidence: :low,
          method: :fallback,
          error: response.error,
          stage: name
        )
      end
    end

    private

    def type_descriptions(registry)
      registry.all.map do |type, schema|
        keywords_sample = schema.keywords.first(3).join(", ")
        "- #{type}: #{schema.display_name} (keywords: #{keywords_sample})"
      end.join("\n")
    end
  end

  # Stage 4: Update the card with inferred type
  class UpdateCard < TaskFrame::Stage
    def perform_work
      card = task.card

      # Get inference result from either KeywordMatch or LlmInfer
      keyword_result = task.result_for(KeywordMatch)
      llm_result = task.result_for(LlmInfer)

      # Use whichever found a type
      inference = if keyword_result&.dig(:type).present?
        keyword_result
      else
        llm_result
      end

      card.update!(
        card_type: inference[:type],
        type_inference_confidence: inference[:confidence].to_s,
        type_inferred_at: Time.current
      )

      Success(
        card: card,
        type: inference[:type],
        confidence: inference[:confidence],
        method: inference[:method],
        stage: name
      )
    end
  end

  # Stage 5: Broadcast update via Turbo Streams
  class Broadcast < TaskFrame::Stage
    def perform_work
      card = task.card

      task.broadcast_replace(
        stream: "board_#{card.board_id}",
        target: "card-#{card.id}",
        partial: "boards/card",
        locals: { card: card, board: card.board }
      )

      Success(broadcast: true, card_id: card.id, stage: name)
    end
  end
end
