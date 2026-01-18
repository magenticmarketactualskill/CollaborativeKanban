# frozen_string_literal: true

class AiSuggestion < ApplicationRecord
  belongs_to :card

  SUGGESTION_TYPES = %w[add_field improve_title add_subtask general].freeze
  STATUSES = %w[pending accepted dismissed].freeze

  validates :suggestion_type, presence: true, inclusion: { in: SUGGESTION_TYPES }
  validates :content, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :accepted, -> { where(status: "accepted") }
  scope :dismissed, -> { where(status: "dismissed") }

  def accept!
    update!(status: "accepted", acted_at: Time.current)
  end

  def dismiss!
    update!(status: "dismissed", acted_at: Time.current)
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
