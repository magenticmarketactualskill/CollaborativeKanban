class User < ApplicationRecord
  ROLES = %w[user admin].freeze
  LOGIN_METHODS = %w[email google github].freeze

  has_many :owned_boards, class_name: 'Board', foreign_key: :owner_id, dependent: :destroy
  has_many :board_members, dependent: :destroy
  has_many :boards, through: :board_members
  has_many :created_cards, class_name: 'Card', foreign_key: :created_by_id, dependent: :nullify
  has_many :card_assignments, dependent: :destroy
  has_many :assigned_cards, through: :card_assignments, source: :card
  has_many :board_activities, dependent: :destroy
  has_one :user_setting, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :open_id, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :login_method, inclusion: { in: LOGIN_METHODS }

  def all_boards
    Board.where(id: owned_boards.select(:id))
         .or(Board.where(id: boards.select(:id)))
  end

  def admin?
    role == 'admin'
  end

  def initials
    name.split.map(&:first).join.upcase[0, 2]
  end
end
