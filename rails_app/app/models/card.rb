class Card < ApplicationRecord
  PRIORITIES = %w[low medium high urgent].freeze

  belongs_to :board
  belongs_to :column
  belongs_to :created_by, class_name: 'User'
  has_many :card_assignments, dependent: :destroy
  has_many :assignees, through: :card_assignments, source: :user

  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_create :set_position

  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :overdue, -> { where('due_date < ?', Date.current) }
  scope :due_soon, -> { where('due_date <= ?', 3.days.from_now) }

  def priority_color
    case priority
    when 'low' then 'blue'
    when 'medium' then 'yellow'
    when 'high' then 'orange'
    when 'urgent' then 'red'
    else 'gray'
    end
  end

  def overdue?
    due_date.present? && due_date < Date.current
  end

  def due_soon?
    due_date.present? && due_date <= 3.days.from_now && !overdue?
  end

  def move_to(new_column, new_position)
    transaction do
      old_column = column
      old_position = position

      if new_column == old_column
        # Moving within same column
        if new_position > old_position
          old_column.cards.where('position > ? AND position <= ?', old_position, new_position)
                    .update_all('position = position - 1')
        else
          old_column.cards.where('position >= ? AND position < ?', new_position, old_position)
                    .update_all('position = position + 1')
        end
      else
        # Moving to different column
        old_column.cards.where('position > ?', old_position).update_all('position = position - 1')
        new_column.cards.where('position >= ?', new_position).update_all('position = position + 1')
        self.column = new_column
      end

      update!(position: new_position)
    end
  end

  private

  def set_position
    self.position ||= column.cards.maximum(:position).to_i + 1
  end
end
