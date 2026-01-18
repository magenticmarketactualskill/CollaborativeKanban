# frozen_string_literal: true

module CardIntelligence
  class ContentAnalyzer
    ANALYSIS_PROMPT = <<~PROMPT
      Analyze this kanban card and provide structured insights.

      Card Type: %{card_type}
      Title: %{title}
      Description: %{description}
      Priority: %{priority}
      Due Date: %{due_date}

      Provide a brief summary, assess complexity (1-5), estimate effort level, and identify any potential blockers, suggested subtasks, or related topics.
    PROMPT

    def analyze(card)
      unless Rails.application.config.llm.enabled
        return AnalysisResult.empty(error: "LLM is disabled")
      end

      prompt = format(
        ANALYSIS_PROMPT,
        card_type: card.card_type,
        title: card.title,
        description: card.description || "(no description)",
        priority: card.priority,
        due_date: card.due_date&.to_s || "(not set)"
      )

      response = Llm::Router.route(:analysis, prompt)

      if response.success?
        parse_analysis(response)
      else
        AnalysisResult.empty(error: response.error)
      end
    end

    def analyze_async(card)
      CardAnalysisJob.perform_later(card.id)
    end

    private

    def parse_analysis(response)
      validation = response.validated_json(:content_analysis)

      if validation.valid?
        json = validation.data
        AnalysisResult.new(
          summary: json["summary"],
          complexity_score: json["complexity_score"]&.to_i,
          estimated_effort: json["estimated_effort"],
          potential_blockers: Array(json["potential_blockers"]),
          suggested_subtasks: Array(json["suggested_subtasks"]),
          related_topics: Array(json["related_topics"]),
          provider: response.provider,
          latency: response.latency
        )
      else
        # Try unvalidated JSON first, then fall back to raw content
        json = response.parsed_json
        if json&.dig("summary")
          Rails.logger.warn("ContentAnalyzer: Schema validation failed, using unvalidated JSON: #{validation.error_messages}")
          AnalysisResult.new(
            summary: json["summary"],
            complexity_score: json["complexity_score"]&.to_i,
            estimated_effort: json["estimated_effort"],
            potential_blockers: Array(json["potential_blockers"]),
            suggested_subtasks: Array(json["suggested_subtasks"]),
            related_topics: Array(json["related_topics"]),
            provider: response.provider,
            latency: response.latency
          )
        else
          Rails.logger.warn("ContentAnalyzer: Invalid response, using raw content fallback")
          AnalysisResult.new(
            summary: response.content.first(200),
            provider: response.provider,
            latency: response.latency
          )
        end
      end
    end

    class AnalysisResult
      attr_reader :summary, :complexity_score, :estimated_effort,
                  :potential_blockers, :suggested_subtasks, :related_topics,
                  :provider, :latency, :error

      def initialize(summary: nil, complexity_score: nil, estimated_effort: nil,
                     potential_blockers: [], suggested_subtasks: [], related_topics: [],
                     provider: nil, latency: nil, error: nil)
        @summary = summary
        @complexity_score = complexity_score
        @estimated_effort = estimated_effort
        @potential_blockers = potential_blockers
        @suggested_subtasks = suggested_subtasks
        @related_topics = related_topics
        @provider = provider
        @latency = latency
        @error = error
      end

      def self.empty(error: nil)
        new(error: error)
      end

      def success?
        error.nil? && summary.present?
      end

      def to_h
        {
          summary: summary,
          complexity_score: complexity_score,
          estimated_effort: estimated_effort,
          potential_blockers: potential_blockers,
          suggested_subtasks: suggested_subtasks,
          related_topics: related_topics
        }
      end
    end
  end
end
