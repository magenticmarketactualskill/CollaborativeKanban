# frozen_string_literal: true

class CardFact < ApplicationRecord
  # Links facts to the cards where they were extracted from or are relevant.
  # This creates a bridge between the structured knowledge graph and task cards.
  #
  # Roles:
  #   - source: The fact was extracted from this card's content
  #   - evidence: The card provides supporting evidence for this fact
  #   - related: The card is tangentially related to this fact

  ROLES = %w[source evidence related].freeze
  SOURCE_FIELDS = %w[title description comment metadata].freeze

  belongs_to :card
  belongs_to :fact

  validates :role, presence: true, inclusion: { in: ROLES }
  validates :source_field, inclusion: { in: SOURCE_FIELDS }, allow_nil: true
  validates :fact_id, uniqueness: { scope: [:card_id, :role] }
  validate :text_offsets_valid

  scope :sources, -> { where(role: "source") }
  scope :evidence, -> { where(role: "evidence") }
  scope :related, -> { where(role: "related") }
  scope :from_field, ->(field) { where(source_field: field) }

  def source?
    role == "source"
  end

  def evidence?
    role == "evidence"
  end

  def related?
    role == "related"
  end

  def excerpt
    return nil unless text_offset_start && text_offset_end

    text = case source_field
           when "title" then card.title
           when "description" then card.description
           else nil
           end

    return nil unless text

    text[text_offset_start..text_offset_end]
  end

  private

  def text_offsets_valid
    return unless text_offset_start || text_offset_end

    if text_offset_start && text_offset_end && text_offset_start > text_offset_end
      errors.add(:text_offset_end, "must be greater than or equal to text_offset_start")
    end

    if text_offset_start && text_offset_start.negative?
      errors.add(:text_offset_start, "must be non-negative")
    end
  end
end
