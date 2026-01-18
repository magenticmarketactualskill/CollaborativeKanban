# frozen_string_literal: true

class ContentAnalysisTask < ApplicationTask
  # Stage indices for progress tracking
  STAGE_VALIDATING = 0
  STAGE_LLM = 1
  STAGE_PROCESSING = 2
  STAGE_SAVING = 3

  def stage_klass_sequence
    [
      ValidateInput,
      CallLlm,
      ParseResponse,
      UpdateCard,
      Broadcast
    ]
  end

  # Broadcast progress update to the loading UI
  def broadcast_stage_progress(stage_index)
    return unless card

    broadcast_replace(
      stream: "card_#{card.id}",
      target: "card-#{card.id}-analysis",
      partial: "cards/analysis_loading",
      locals: { card: card, stage: stage_index }
    )
  end

  # Stage 1: Validate input and find card
  class ValidateInput < TaskFrame::Stage
    include FindsCard

    def preconditions_met?
      Rails.application.config.llm.enabled
    end

    def perform_work
      result = find_card
      return result if result.failure?

      card = result.value![:card]

      # Broadcast that we're moving to the analyzing stage
      task.broadcast_stage_progress(ContentAnalysisTask::STAGE_LLM)

      Success(
        card: card,
        card_type: card.card_type,
        title: card.title,
        description: card.description,
        priority: card.priority,
        due_date: card.due_date
      )
    end
  end

  # Stage 2: Call LLM for analysis
  class CallLlm < TaskFrame::Stage
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

    def perform_work
      input = task.result_for(ValidateInput)

      prompt = format(
        ANALYSIS_PROMPT,
        card_type: input[:card_type],
        title: input[:title],
        description: input[:description] || "(no description)",
        priority: input[:priority],
        due_date: input[:due_date]&.to_s || "(not set)"
      )

      response = LlmClient::Llm::Router.route(:analysis, prompt)

      if response.success?
        # Broadcast that we're moving to processing stage
        task.broadcast_stage_progress(ContentAnalysisTask::STAGE_PROCESSING)

        Success(
          response: response,
          content: response.content,
          provider: response.provider,
          latency: response.latency,
          stage: name
        )
      else
        Failure(
          error: response.error,
          provider: response.provider,
          stage: name
        )
      end
    end
  end

  # Stage 3: Parse the LLM response into structured data
  class ParseResponse < TaskFrame::Stage
    def perform_work
      llm_result = task.result_for(CallLlm)
      response = llm_result[:response]

      # Broadcast that we're moving to saving stage
      task.broadcast_stage_progress(ContentAnalysisTask::STAGE_SAVING)

      validation = response.validated_json(:content_analysis)

      if validation.valid?
        json = validation.data
        Success(
          summary: json["summary"],
          complexity_score: json["complexity_score"]&.to_i,
          estimated_effort: json["estimated_effort"],
          potential_blockers: Array(json["potential_blockers"]),
          suggested_subtasks: Array(json["suggested_subtasks"]),
          related_topics: Array(json["related_topics"]),
          provider: llm_result[:provider],
          latency: llm_result[:latency],
          stage: name
        )
      else
        # Fallback: try raw parsed JSON without validation
        json = response.parsed_json
        if json
          Success(
            summary: json["summary"] || llm_result[:content].to_s.first(200),
            complexity_score: json["complexity_score"]&.to_i,
            estimated_effort: json["estimated_effort"],
            potential_blockers: Array(json["potential_blockers"]),
            suggested_subtasks: Array(json["suggested_subtasks"]),
            related_topics: Array(json["related_topics"]),
            provider: llm_result[:provider],
            latency: llm_result[:latency],
            fallback: true,
            stage: name
          )
        else
          # Last resort: extract useful content even if not valid JSON
          Success(
            summary: llm_result[:content].to_s.first(200),
            complexity_score: nil,
            estimated_effort: nil,
            potential_blockers: [],
            suggested_subtasks: [],
            related_topics: [],
            provider: llm_result[:provider],
            latency: llm_result[:latency],
            fallback: true,
            stage: name
          )
        end
      end
    end
  end

  # Stage 4: Update the card with analysis results
  class UpdateCard < TaskFrame::Stage
    def perform_work
      card = task.card
      analysis = task.result_for(ParseResponse)

      card.update!(
        ai_summary: analysis[:summary],
        ai_analyzed_at: Time.current
      )

      # Store detailed analysis in metadata
      card.update_column(:card_metadata, card.card_metadata.merge(
        "ai_analysis" => {
          summary: analysis[:summary],
          complexity_score: analysis[:complexity_score],
          estimated_effort: analysis[:estimated_effort],
          potential_blockers: analysis[:potential_blockers],
          suggested_subtasks: analysis[:suggested_subtasks],
          related_topics: analysis[:related_topics]
        },
        "ai_analysis_provider" => analysis[:provider].to_s
      ))

      Success(
        card: card,
        summary: analysis[:summary],
        provider: analysis[:provider],
        stage: name
      )
    end
  end

  # Stage 5: Broadcast update via Turbo Streams
  class Broadcast < TaskFrame::Stage
    def perform_work
      card = task.card
      analysis = task.result_for(ParseResponse)

      # Build an analysis result object for the partial
      analysis_result = OpenStruct.new(
        summary: analysis[:summary],
        complexity_score: analysis[:complexity_score],
        estimated_effort: analysis[:estimated_effort],
        potential_blockers: analysis[:potential_blockers],
        suggested_subtasks: analysis[:suggested_subtasks],
        related_topics: analysis[:related_topics],
        provider: analysis[:provider],
        latency: analysis[:latency]
      )

      task.broadcast_update(
        stream: "card_#{card.id}",
        target: "card-#{card.id}-analysis",
        partial: "cards/analysis",
        locals: { card: card, analysis: analysis_result }
      )

      Success(broadcast: true, card_id: card.id, stage: name)
    end
  end
end
