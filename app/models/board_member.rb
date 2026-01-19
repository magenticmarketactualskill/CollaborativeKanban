class BoardMember < ApplicationRecord
  ROLES = %w[viewer editor admin].freeze

  belongs_to :board
  belongs_to :user

  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: :board_id, message: 'is already a member of this board' }

  def can_edit?
    %w[editor admin].include?(role)
  end

  def can_admin?
    role == 'admin'
  end
end
