class BoardActivity < ApplicationRecord
  ACTIVITY_TYPES = %w[viewing editing_card moving_card].freeze

  belongs_to :board
  belongs_to :user
  belongs_to :card, optional: true

  validates :activity_type, inclusion: { in: ACTIVITY_TYPES }

  scope :recent, -> { where('last_active_at > ?', 5.minutes.ago) }
  scope :active_users, -> { recent.select(:user_id).distinct }

  before_save :update_last_active_at

  private

  def update_last_active_at
    self.last_active_at = Time.current
  end
end
