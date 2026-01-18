class McpServerConfiguration < ApplicationRecord
  AUTH_TYPES = %w[none token oauth].freeze

  belongs_to :user, optional: true

  validates :name, presence: true
  validates :port, numericality: { in: 1024..65535 }
  validates :auth_type, inclusion: { in: AUTH_TYPES }

  scope :enabled, -> { where(enabled: true) }
  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: [ nil, user&.id ]) }

  def self.current(user = nil)
    for_user(user).order(user_id: :desc).first || new(name: "Default", enabled: true)
  end

  def tool_enabled?(tool_name)
    enabled_tools.empty? || enabled_tools.include?(tool_name)
  end

  def resource_enabled?(resource_name)
    enabled_resources.empty? || enabled_resources.include?(resource_name)
  end

  def auth_required?
    auth_type != "none"
  end

  def valid_token?(token)
    return true unless auth_type == "token"
    auth_token.present? && ActiveSupport::SecurityUtils.secure_compare(auth_token, token.to_s)
  end
end
