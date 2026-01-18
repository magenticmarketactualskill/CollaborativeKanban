# frozen_string_literal: true

class RelationshipDetectionTask < ApplicationTask
  # Stage indices for progress tracking
  STAGE_PREPARING = 0
  STAGE_ANALYZING = 1
  STAGE_PROCESSING = 2
  STAGE_SAVING = 3

  def stage_klass_sequence
    [
      ValidateInput,
      DetectRelationships,
      ParseSuggestions,
      SaveRecords,
      Broadcast
    ]
  end

  def broadcast_stage_progress(stage_index)
    return unless card

    broadcast_replace(
      stream: "card_#{card.id}_relationships",
      target: "card-#{card.id}-relationship-suggestions",
      partial: "cards/relationship_suggestions_loading",
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
      other_cards = card.board.cards.where.not(id: card.id).limit(50)

      if other_cards.empty?
        return Failure(error: "No other cards on board to analyze", stage: name)
      end

      task.broadcast_stage_progress(RelationshipDetectionTask::STAGE_ANALYZING)

      Success(
        card: card,
        other_cards: other_cards.map { |c|
          { id: c.id, title: c.title, description: c.description&.truncate(200), card_type: c.card_type }
        }
      )
    end
  end

  # Stage 2: Call LLM to detect relationships
  class DetectRelationships < TaskFrame::Stage
    RELATIONSHIP_PROMPT = <<~PROMPT
      Analyze the following kanban card and compare it to other cards on the same board to identify potential relationships.

      ## Current Card
      ID: %{card_id}
      Title: %{title}
      Description: %{description}
      Card Type: %{card_type}
      Priority: %{priority}

      ## Other Cards on Board
      %{other_cards}

      ## Instructions
      Identify relationships between the current card and other cards:

      1. **Dependency Detection**: Look for language indicating dependencies:
         - "after X is done", "requires Y", "waiting on", "depends on", "blocked by"
         - "once Z is complete", "prerequisite", "needs"

      2. **Content Similarity**: Identify cards that are related by:
         - Similar topics, technologies, or domains
         - Part of the same feature or epic
         - Complementary tasks

      3. **Blocking Detection**: Look for language indicating this card blocks others:
         - "before we can", "prerequisite for", "blocks", "needed for"

      Respond with a JSON object containing a "relationships" array.
      Each relationship should have:
      - target_card_id: The ID of the related card (integer)
      - relationship_type: One of "blocks", "depends_on", or "related_to"
      - confidence: "high", "medium", or "low"
      - reasoning: Brief explanation (max 500 chars)

      Only include relationships you are reasonably confident about. Return {"relationships": []} if no clear relationships exist.
    PROMPT

    def perform_work
      input = task.result_for(ValidateInput)
      card = task.card

      other_cards_text = input[:other_cards].map do |c|
        "- ID: #{c[:id]}, Title: #{c[:title]}, Description: #{c[:description] || '(none)'}, Type: #{c[:card_type]}"
      end.join("\n")

      prompt = format(
        RELATIONSHIP_PROMPT,
        card_id: card.id,
        title: card.title,
        description: card.description || "(no description)",
        card_type: card.card_type,
        priority: card.priority,
        other_cards: other_cards_text
      )

      response = Llm::Router.route(:relationship_detection, prompt)

      if response.success?
        task.broadcast_stage_progress(RelationshipDetectionTask::STAGE_PROCESSING)
        Success(response: response, provider: response.provider, stage: name)
      else
        Failure(error: response.error, provider: response.provider, stage: name)
      end
    end
  end

  # Stage 3: Parse suggestions from LLM response
  class ParseSuggestions < TaskFrame::Stage
    def perform_work
      llm_result = task.result_for(DetectRelationships)
      response = llm_result[:response]
      card = task.card

      validation = response.validated_json(:relationship_suggestions)

      relationships_data = if validation.valid?
        validation.data["relationships"] || []
      else
        json = response.parsed_json
        json.is_a?(Hash) ? (json["relationships"] || []) : []
      end

      task.broadcast_stage_progress(RelationshipDetectionTask::STAGE_SAVING)

      suggestions = relationships_data.filter_map do |item|
        next unless valid_suggestion?(item, card)

        {
          card: card,
          suggestion_type: 'add_relationship',
          content: {
            target_card_id: item["target_card_id"],
            relationship_type: item["relationship_type"],
            confidence: item["confidence"] || "medium",
            reasoning: item["reasoning"] || ""
          }.to_json,
          provider: llm_result[:provider].to_s
        }
      end

      Success(suggestions: suggestions, stage: name)
    end

    private

    def valid_suggestion?(item, card)
      return false unless item.is_a?(Hash)
      return false unless item["target_card_id"].present?
      return false unless CardRelationship::RELATIONSHIP_TYPES.include?(item["relationship_type"])

      target = Card.find_by(id: item["target_card_id"])
      return false unless target && target.board_id == card.board_id

      !CardRelationship.exists?(
        source_card_id: card.id,
        target_card_id: item["target_card_id"],
        relationship_type: item["relationship_type"]
      )
    end
  end

  # Stage 4: Save suggestion records
  class SaveRecords < TaskFrame::Stage
    def perform_work
      card = task.card
      parsed = task.result_for(ParseSuggestions)

      card.ai_suggestions.pending.where(suggestion_type: 'add_relationship').destroy_all

      saved = parsed[:suggestions].filter_map do |data|
        suggestion = AiSuggestion.new(data)
        suggestion if suggestion.save
      end

      Success(suggestions: saved, count: saved.length, stage: name)
    end
  end

  # Stage 5: Broadcast update
  class Broadcast < TaskFrame::Stage
    def perform_work
      card = task.card
      saved = task.result_for(SaveRecords)
      suggestions = saved[:suggestions]

      if suggestions.any?
        task.broadcast_replace(
          stream: "card_#{card.id}_relationships",
          target: "card-#{card.id}-relationship-suggestions",
          partial: "cards/relationship_suggestions",
          locals: { card: card, suggestions: suggestions }
        )
      else
        task.broadcast_replace(
          stream: "card_#{card.id}_relationships",
          target: "card-#{card.id}-relationship-suggestions",
          partial: "cards/relationship_suggestions_empty",
          locals: { card: card }
        )
      end

      Success(broadcast: true, card_id: card.id, count: suggestions.length, stage: name)
    end
  end
end
