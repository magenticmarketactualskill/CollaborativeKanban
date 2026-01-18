# frozen_string_literal: true

module CardIntelligence
  class RelationshipDetector
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

      For each relationship found, respond with a JSON object containing a "relationships" array.
      Each relationship should have:
      - target_card_id: The ID of the related card (integer)
      - relationship_type: One of "blocks", "depends_on", or "related_to"
      - confidence: "high", "medium", or "low"
      - reasoning: Brief explanation (max 500 chars)

      Only include relationships you are reasonably confident about. Return an empty array if no clear relationships exist.
    PROMPT

    def detect(card)
      unless Rails.application.config.llm.enabled
        return []
      end

      other_cards = card.board.cards.where.not(id: card.id).limit(50)
      return [] if other_cards.empty?

      prompt = build_prompt(card, other_cards)
      response = Llm::Router.route(:relationship_detection, prompt)

      if response.success?
        parse_suggestions(response, card)
      else
        Rails.logger.warn("RelationshipDetector: LLM call failed: #{response.error}")
        []
      end
    end

    def detect_async(card)
      RelationshipDetectionJob.perform_later(card.id)
    end

    private

    def build_prompt(card, other_cards)
      other_cards_text = other_cards.map do |c|
        "- ID: #{c.id}, Title: #{c.title}, Description: #{c.description&.truncate(200) || '(none)'}, Type: #{c.card_type}"
      end.join("\n")

      format(
        RELATIONSHIP_PROMPT,
        card_id: card.id,
        title: card.title,
        description: card.description || "(no description)",
        card_type: card.card_type,
        priority: card.priority,
        other_cards: other_cards_text
      )
    end

    def parse_suggestions(response, card)
      validation = response.validated_json(:relationship_suggestions)

      suggestions_data = if validation.valid?
        validation.data["relationships"] || []
      else
        json = response.parsed_json
        if json.is_a?(Hash) && json["relationships"].is_a?(Array)
          Rails.logger.warn("RelationshipDetector: Schema validation failed, using unvalidated JSON")
          json["relationships"]
        else
          Rails.logger.warn("RelationshipDetector: Invalid response format")
          return []
        end
      end

      suggestions_data.filter_map do |item|
        next unless valid_suggestion?(item, card)

        AiSuggestion.new(
          card: card,
          suggestion_type: 'add_relationship',
          content: build_suggestion_content(item),
          field_name: nil,
          provider: response.provider.to_s
        )
      end
    rescue StandardError => e
      Rails.logger.error("RelationshipDetector: Parse error: #{e.message}")
      []
    end

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

    def build_suggestion_content(item)
      {
        target_card_id: item["target_card_id"],
        relationship_type: item["relationship_type"],
        confidence: item["confidence"] || "medium",
        reasoning: item["reasoning"] || ""
      }.to_json
    end
  end
end
