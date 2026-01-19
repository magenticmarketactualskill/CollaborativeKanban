# frozen_string_literal: true

class Fact < EntityKnowledge::Fact
  # App-specific associations
  belongs_to :created_by, class_name: "User", optional: true
  has_many :card_facts, dependent: :destroy
  has_many :cards, through: :card_facts

  # App-specific validation
  validate :subject_and_object_in_same_board

  private

  def subject_and_object_in_same_board
    return unless object_entity_id.present?
    return unless subject_entity&.domain && object_entity&.domain

    if subject_entity.domain.board_id != object_entity.domain.board_id
      errors.add(:object_entity, "must be in the same board as subject entity")
    end
  end
end
