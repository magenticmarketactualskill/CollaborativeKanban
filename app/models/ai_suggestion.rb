# frozen_string_literal: true

class AiSuggestion < ApplicationRecord
  belongs_to :card

  SUGGESTION_TYPES = %w[add_field improve_title add_subtask general add_relationship].freeze
  STATUSES = %w[pending accepted dismissed].freeze

  validates :suggestion_type, presence: true, inclusion: { in: SUGGESTION_TYPES }
  validates :content, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :dismissed, -> { where(status: "dismissed") }

  def accept!
    if suggestion_type == 'add_relationship' && relationship_data.present?
      CardRelationship.create!(
        source_card: card,
        target_card_id: relationship_data['target_card_id'],
        relationship_type: relationship_data['relationship_type'],
        created_by: nil
      )
    end

    update!(status: "accepted", acted_at: Time.current)
  end

  def dismiss!
    update!(status: "dismissed", acted_at: Time.current)
  end

  # Relationship suggestion helpers
  def relationship_data
    return nil unless suggestion_type == 'add_relationship'
    @relationship_data ||= JSON.parse(content) rescue nil
  end

  def target_card
    return nil unless relationship_data
    Card.find_by(id: relationship_data['target_card_id'])
  end

  def relationship_type_name
    relationship_data&.dig('relationship_type')
  end

  def confidence
    relationship_data&.dig('confidence')
  end

  def reasoning
    relationship_data&.dig('reasoning')
  end

  def pending?
    status == "pending"
  end

  def accepted?
    status == "accepted"
  end

  def dismissed?
    status == "dismissed"
  end
end
