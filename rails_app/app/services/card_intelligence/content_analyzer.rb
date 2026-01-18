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

      Provide your analysis in the following JSON format:
      {
        "summary": "One sentence summary of what this card is about",
        "complexity_score": 1-5,
        "estimated_effort": "low/medium/high",
        "potential_blockers": ["list of potential issues or dependencies"],
        "suggested_subtasks": ["list of subtasks if this card could be broken down"],
        "related_topics": ["list of related areas, technologies, or concepts"]
      }

      Respond ONLY with valid JSON, no additional text.
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
      json = response.parsed_json

      if json
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
        # Try to extract useful content even if not valid JSON
        AnalysisResult.new(
          summary: response.content.first(200),
          provider: response.provider,
          latency: response.latency
        )
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
