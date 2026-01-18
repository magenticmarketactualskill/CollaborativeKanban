# frozen_string_literal: true

class SuggestionGenerationTask < ApplicationTask
  # Stage indices for progress tracking
  STAGE_PREPARING = 0
  STAGE_LLM = 1
  STAGE_PROCESSING = 2
  STAGE_SAVING = 3

  def stage_klass_sequence
    [
      ValidateInput,
      GenerateSuggestions,
      ParseSuggestions,
      SaveRecords,
      Broadcast
    ]
  end

  # Broadcast progress update to the loading UI
  def broadcast_stage_progress(stage_index)
    return unless card

    broadcast_replace(
      stream: "card_#{card.id}_suggestions",
      target: "card-#{card.id}-suggestions",
      partial: "cards/suggestions_loading",
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
      schema = CardSchemas::Registry.instance.schema_for_card(card)

      # Broadcast that we're moving to the generating stage
      task.broadcast_stage_progress(SuggestionGenerationTask::STAGE_LLM)

      Success(
        card: card,
        card_type: card.card_type,
        title: card.title,
        description: card.description,
        priority: card.priority,
        schema_fields: schema.fields.map { |f| "#{f.name} (#{f.type})" }.join(", "),
        current_metadata: card.card_metadata.to_json
      )
    end
  end

  # Stage 2: Call LLM to generate suggestions
  class GenerateSuggestions < TaskFrame::Stage
    SUGGESTION_PROMPT = <<~PROMPT
      You are helping a user improve their kanban card. Based on the card information below, provide helpful suggestions.

      Card Type: %{card_type}
      Title: %{title}
      Description: %{description}
      Current Priority: %{priority}
      Available Fields: %{schema_fields}
      Current Metadata: %{current_metadata}

      Provide 2-3 actionable suggestions to improve this card. Focus on:
      1. Missing information that would be helpful based on the card type
      2. Ways to make the title/description clearer or more actionable
      3. Suggestions for breaking down complex tasks into subtasks

      Format as JSON array:
      [
        {"type": "add_field", "field": "field_name", "suggestion": "why and what to add"},
        {"type": "improve_title", "suggestion": "suggested improvement to the title"},
        {"type": "add_subtask", "suggestion": "suggested subtask to break this down"}
      ]

      Respond ONLY with valid JSON array.
    PROMPT

    def perform_work
      input = task.result_for(ValidateInput)

      prompt = format(
        SUGGESTION_PROMPT,
        card_type: input[:card_type],
        title: input[:title],
        description: input[:description] || "(no description)",
        priority: input[:priority],
        schema_fields: input[:schema_fields],
        current_metadata: input[:current_metadata]
      )

      response = Llm::Router.route(:suggestion, prompt)

      if response.success?
        # Broadcast that we're moving to processing stage
        task.broadcast_stage_progress(SuggestionGenerationTask::STAGE_PROCESSING)

        Success(
          response: response,
          content: response.content,
          provider: response.provider,
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

  # Stage 3: Parse suggestions from LLM response
  class ParseSuggestions < TaskFrame::Stage
    def perform_work
      llm_result = task.result_for(GenerateSuggestions)
      response = llm_result[:response]

      # Broadcast that we're moving to saving stage
      task.broadcast_stage_progress(SuggestionGenerationTask::STAGE_SAVING)

      validation = response.validated_json(:suggestions)

      suggestions_data = if validation.valid?
        validation.data
      else
        # Fallback to raw parsed JSON
        json = response.parsed_json
        json.is_a?(Array) ? json : []
      end

      card = task.card
      suggestions = suggestions_data.filter_map do |item|
        next unless item.is_a?(Hash) && item["suggestion"].present?

        {
          card: card,
          suggestion_type: item["type"] || "general",
          field_name: item["field"],
          content: item["suggestion"],
          provider: llm_result[:provider].to_s
        }
      end

      Success(suggestions: suggestions, provider: llm_result[:provider], stage: name)
    rescue StandardError => e
      Rails.logger.error("Failed to parse suggestions: #{e.message}")
      Success(suggestions: [], provider: llm_result[:provider], stage: name)
    end
  end

  # Stage 4: Save suggestion records to database
  class SaveRecords < TaskFrame::Stage
    def perform_work
      card = task.card
      parsed = task.result_for(ParseSuggestions)

      # Clear old pending suggestions
      card.ai_suggestions.pending.destroy_all

      # Save new suggestions
      saved_suggestions = parsed[:suggestions].filter_map do |suggestion_data|
        suggestion = AiSuggestion.new(suggestion_data)
        suggestion if suggestion.save
      end

      Success(
        suggestions: saved_suggestions,
        count: saved_suggestions.length,
        stage: name
      )
    end
  end

  # Stage 5: Broadcast update via Turbo Streams
  class Broadcast < TaskFrame::Stage
    def perform_work
      card = task.card
      saved = task.result_for(SaveRecords)
      suggestions = saved[:suggestions]

      if suggestions.any?
        task.broadcast_replace(
          stream: "card_#{card.id}_suggestions",
          target: "card-#{card.id}-suggestions",
          partial: "cards/suggestions",
          locals: { card: card, suggestions: suggestions }
        )
      end

      Success(
        broadcast: suggestions.any?,
        card_id: card.id,
        suggestion_count: suggestions.length,
        stage: name
      )
    end
  end
end
