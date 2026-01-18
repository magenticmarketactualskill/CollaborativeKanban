# frozen_string_literal: true

module CardIntelligence
  class SuggestionGenerator
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

    def generate(card)
      unless Rails.application.config.llm.enabled
        return []
      end

      schema = CardSchemas::Registry.instance.schema_for_card(card)

      prompt = format(
        SUGGESTION_PROMPT,
        card_type: card.card_type,
        title: card.title,
        description: card.description || "(no description)",
        priority: card.priority,
        schema_fields: schema.fields.map { |f| "#{f.name} (#{f.type})" }.join(", "),
        current_metadata: card.card_metadata.to_json
      )

      response = Llm::Router.route(:suggestion, prompt)

      if response.success?
        parse_suggestions(response, card)
      else
        []
      end
    end

    def generate_async(card)
      SuggestionGenerationJob.perform_later(card.id)
    end

    private

    def parse_suggestions(response, card)
      json = response.parsed_json
      return [] unless json.is_a?(Array)

      json.filter_map do |item|
        next unless item.is_a?(Hash) && item["suggestion"].present?

        AiSuggestion.new(
          card: card,
          suggestion_type: item["type"] || "general",
          field_name: item["field"],
          content: item["suggestion"],
          provider: response.provider.to_s
        )
      end
    rescue StandardError => e
      Rails.logger.error("Failed to parse suggestions: #{e.message}")
      []
    end
  end
end
