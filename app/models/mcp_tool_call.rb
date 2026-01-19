class McpToolCall < ApplicationRecord
  DIRECTIONS = %w[inbound outbound].freeze
  STATUSES = %w[pending success error].freeze

  belongs_to :mcp_client_connection, optional: true
  belongs_to :user, optional: true

  validates :tool_name, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }

  scope :inbound, -> { where(direction: "inbound") }
  scope :outbound, -> { where(direction: "outbound") }
  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "error") }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_user, ->(user) { where(user: user) }

  def self.log_inbound(tool_name:, arguments:, user: nil)
    create!(
      tool_name: tool_name,
      direction: "inbound",
      arguments: arguments,
      status: "pending",
      user: user,
      started_at: Time.current
    )
  end

  def self.log_outbound(tool_name:, arguments:, connection:, user: nil)
    create!(
      tool_name: tool_name,
      direction: "outbound",
      arguments: arguments,
      status: "pending",
      mcp_client_connection: connection,
      user: user,
      started_at: Time.current
    )
  end

  def complete!(result)
    update!(
      result: result,
      status: "success",
      completed_at: Time.current,
      latency_ms: calculate_latency
    )
  end

  def fail!(error_message)
    update!(
      error_message: error_message,
      status: "error",
      completed_at: Time.current,
      latency_ms: calculate_latency
    )
  end

  def inbound?
    direction == "inbound"
  end

  def outbound?
    direction == "outbound"
  end

  private

  def calculate_latency
    return nil unless started_at
    ((Time.current - started_at) * 1000).to_i
  end
end
