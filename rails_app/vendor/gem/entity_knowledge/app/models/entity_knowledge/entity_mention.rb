# frozen_string_literal: true

module EntityKnowledge
  class EntityMention < ApplicationRecord
    # Tracks where entities are mentioned in content.
    # Enables entity linking and provides the raw evidence for fact extraction.
    #
    # Example: Text "Fix auth bug reported by John" would create:
    #   - EntityMention(entity: "auth", mention_text: "auth", source_field: "content")
    #   - EntityMention(entity: "John Smith", mention_text: "John", source_field: "content")

    self.table_name = "entity_mentions"

    EXTRACTION_METHODS = %w[manual ai_llm ai_pattern fuzzy_match].freeze
    SOURCE_FIELDS = %w[title description comment content].freeze

    belongs_to :entity, class_name: "EntityKnowledge::Entity"

    validates :mention_text, presence: true, length: { maximum: 500 }
    validates :source_field, presence: true, inclusion: { in: SOURCE_FIELDS }
    validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :extraction_method, inclusion: { in: EXTRACTION_METHODS }, allow_nil: true

    scope :in_title, -> { where(source_field: "title") }
    scope :in_description, -> { where(source_field: "description") }
    scope :in_content, -> { where(source_field: "content") }
    scope :high_confidence, -> { where("confidence >= ?", 0.8) }
    scope :ai_extracted, -> { where(extraction_method: %w[ai_llm ai_pattern fuzzy_match]) }

    def ai_extracted?
      %w[ai_llm ai_pattern fuzzy_match].include?(extraction_method)
    end

    def needs_review?
      ai_extracted? && confidence < 0.8
    end

    def has_position?
      text_offset_start.present? && text_offset_end.present?
    end
  end
end
