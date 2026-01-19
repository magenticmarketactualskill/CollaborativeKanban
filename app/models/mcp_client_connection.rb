class McpClientConnection < ApplicationRecord
  AUTH_TYPES = %w[none token oauth].freeze
  STATUSES = %w[disconnected connecting connected error].freeze

  belongs_to :user, optional: true
  has_many :mcp_tool_calls, dependent: :nullify

  validates :name, presence: true
  validates :url, presence: true, format: { with: /\Awss?:\/\//, message: "must be a WebSocket URL (ws:// or wss://)" }
  validates :auth_type, inclusion: { in: AUTH_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :name, uniqueness: { scope: :user_id }

  scope :enabled, -> { where(enabled: true) }
  scope :connected, -> { where(status: "connected") }
  scope :for_user, ->(user) { where(user_id: [ nil, user&.id ]) }

  def available_tools
    cached_tools.map { |t| Mcp::Client::ToolDefinition.new(t.symbolize_keys) }
  end

  def tool_by_name(name)
    available_tools.find { |t| t.name == name }
  end

  def mark_connected!
    update!(status: "connected", last_connected_at: Time.current, last_error: nil)
  end

  def mark_disconnected!
    update!(status: "disconnected")
  end

  def mark_error!(message)
    update!(status: "error", last_error: message)
  end

  def update_capabilities(tools:, resources:, prompts:)
    update!(
      cached_tools: tools || [],
      cached_resources: resources || [],
      cached_prompts: prompts || []
    )
  end
end
