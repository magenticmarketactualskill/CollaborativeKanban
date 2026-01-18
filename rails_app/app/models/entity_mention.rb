# frozen_string_literal: true

class EntityMention < ApplicationRecord
  # Tracks where entities are mentioned in card content.
  # Enables entity linking and provides the raw evidence for fact extraction.
  #
  # Example: Card title "Fix auth bug reported by John" would create:
  #   - EntityMention(entity: "auth", mention_text: "auth", source_field: "title")
  #   - EntityMention(entity: "John Smith", mention_text: "John", source_field: "title")

  EXTRACTION_METHODS = %w[manual ai_llm ai_pattern fuzzy_match].freeze
  SOURCE_FIELDS = %w[title description comment].freeze

  belongs_to :entity
  belongs_to :card

  validates :mention_text, presence: true, length: { maximum: 500 }
  validates :source_field, presence: true, inclusion: { in: SOURCE_FIELDS }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :extraction_method, inclusion: { in: EXTRACTION_METHODS }, allow_nil: true

  scope :in_title, -> { where(source_field: "title") }
  scope :in_description, -> { where(source_field: "description") }
  scope :high_confidence, -> { where("confidence >= ?", 0.8) }
  scope :ai_extracted, -> { where(extraction_method: %w[ai_llm ai_pattern fuzzy_match]) }

  def ai_extracted?
    %w[ai_llm ai_pattern fuzzy_match].include?(extraction_method)
  end

  def needs_review?
    ai_extracted? && confidence < 0.8
  end

  def excerpt_with_context(context_chars: 50)
    text = case source_field
           when "title" then card.title
           when "description" then card.description
           else nil
           end

    return mention_text unless text && text_offset_start && text_offset_end

    start_pos = [0, text_offset_start - context_chars].max
    end_pos = [text.length, text_offset_end + context_chars].min

    prefix = start_pos > 0 ? "..." : ""
    suffix = end_pos < text.length ? "..." : ""

    "#{prefix}#{text[start_pos...end_pos]}#{suffix}"
  end
end
