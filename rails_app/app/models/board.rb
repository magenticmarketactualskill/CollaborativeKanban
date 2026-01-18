class Board < ApplicationRecord
  LEVELS = %w[personal team group enterprise].freeze

  belongs_to :owner, class_name: 'User'
  has_many :columns, -> { order(position: :asc) }, dependent: :destroy
  has_many :cards, dependent: :destroy
  has_many :board_members, dependent: :destroy
  has_many :members, through: :board_members, source: :user
  has_many :board_activities, dependent: :destroy
  has_many :domains, dependent: :destroy
  has_many :entities, through: :domains

  validates :name, presence: true
  validates :level, inclusion: { in: LEVELS }

  after_create :create_default_columns

  def user_role(user)
    return 'owner' if owner_id == user.id
    board_members.find_by(user: user)&.role
  end

  def user_can_edit?(user)
    role = user_role(user)
    %w[owner admin editor].include?(role)
  end

  def user_can_admin?(user)
    role = user_role(user)
    %w[owner admin].include?(role)
  end

  def level_color
    case level
    when 'personal' then 'blue'
    when 'team' then 'green'
    when 'group' then 'purple'
    when 'enterprise' then 'orange'
    else 'gray'
    end
  end

  private

  def create_default_columns
    columns.create!([
      { name: 'To Do', position: 0 },
      { name: 'In Progress', position: 1 },
      { name: 'Done', position: 2 }
    ])
  end
end
