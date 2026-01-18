class Column < ApplicationRecord
  belongs_to :board
  has_many :cards, -> { order(position: :asc) }, dependent: :destroy

  validates :name, presence: true
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  before_create :set_position

  def cards_count
    cards.count
  end

  private

  def set_position
    self.position ||= board.columns.maximum(:position).to_i + 1
  end
end
