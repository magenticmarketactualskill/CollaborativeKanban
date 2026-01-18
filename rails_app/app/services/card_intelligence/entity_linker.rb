# frozen_string_literal: true

module CardIntelligence
  class EntityLinker
    # Card-aware wrapper around EntityKnowledge::Extraction::EntityLinker.
    # Links text mentions in cards to known entities using fuzzy matching.

    def initialize(fuzzy_threshold: nil)
      @linker = EntityKnowledge::Extraction::EntityLinker.new(fuzzy_threshold: fuzzy_threshold)
    end

    def link(card, entities)
      mentions = []

      # Convert ActiveRecord entities to hash format expected by gem
      entity_data = entities.map do |entity|
        {
          id: entity.id,
          name: entity.name,
          aliases: entity.aliases || []
        }
      end

      text_fields = [
        { field: "title", text: card.title },
        { field: "description", text: card.description }
      ].compact_blank

      text_fields.each do |field_info|
        next if field_info[:text].blank?

        result = @linker.link(field_info[:text], entity_data, source_field: field_info[:field])
        mentions.concat(result[:mentions])
      end

      { mentions: deduplicate_mentions(mentions) }
    end

    private

    def deduplicate_mentions(mentions)
      mentions
        .group_by { |m| [m[:entity_id], m[:offset_start]] }
        .values
        .map { |group| group.max_by { |m| m[:confidence] } }
    end
  end
end
