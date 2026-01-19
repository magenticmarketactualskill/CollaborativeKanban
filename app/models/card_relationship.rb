# frozen_string_literal: true

class CardRelationship < ApplicationRecord
  RELATIONSHIP_TYPES = %w[blocks depends_on related_to].freeze

  INVERSE_TYPES = {
    "blocks" => "blocked_by",
    "blocked_by" => "blocks",
    "depends_on" => "dependency_of",
    "dependency_of" => "depends_on",
    "related_to" => "related_to"
  }.freeze

  belongs_to :source_card, class_name: 'Card'
  belongs_to :target_card, class_name: 'Card'
  belongs_to :created_by, class_name: 'User', optional: true

  validates :relationship_type, presence: true, inclusion: { in: RELATIONSHIP_TYPES }
  validate :cards_must_be_different
  validate :cards_on_same_board
  validate :no_duplicate_inverse

  scope :blocking, -> { where(relationship_type: 'blocks') }
  scope :dependencies, -> { where(relationship_type: 'depends_on') }
  scope :related, -> { where(relationship_type: 'related_to') }

  def inverse_type
    INVERSE_TYPES[relationship_type]
  end

  def symmetric?
    relationship_type == 'related_to'
  end

  private

  def cards_must_be_different
    return unless source_card_id.present? && target_card_id.present?

    if source_card_id == target_card_id
      errors.add(:base, "A card cannot have a relationship with itself")
    end
  end

  def cards_on_same_board
    return unless source_card && target_card

    if source_card.board_id != target_card.board_id
      errors.add(:base, "Cards must be on the same board")
    end
  end

  def no_duplicate_inverse
    return unless relationship_type == 'related_to'
    return unless source_card_id.present? && target_card_id.present?

    if CardRelationship.exists?(
      source_card_id: target_card_id,
      target_card_id: source_card_id,
      relationship_type: 'related_to'
    )
      errors.add(:base, "This relationship already exists")
    end
  end
end
