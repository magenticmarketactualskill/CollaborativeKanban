class LlmStage < ApplicationRecord
  STATUSES = %w[pending in_progress completed failed skipped].freeze

  belongs_to :llm_call

  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :skipped, -> { where(status: "skipped") }
  scope :by_position, -> { order(position: :asc) }
  scope :for_type, ->(stage_type) { where(stage_type: stage_type) }

  # Delegate configuration access through llm_call
  delegate :llm_configuration, to: :llm_call

  def start!
    update!(status: "in_progress", started_at: Time.current)
  end

  def complete!(response_content:, latency_ms: nil, input_tokens: nil, output_tokens: nil)
    update!(
      status: "completed",
      response_content: response_content,
      latency_ms: latency_ms,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      completed_at: Time.current
    )
  end

  def fail!(error_message:)
    update!(
      status: "failed",
      error_message: error_message,
      completed_at: Time.current
    )
  end

  def skip!(reason: nil)
    update!(
      status: "skipped",
      error_message: reason,
      completed_at: Time.current
    )
  end

  def duration_ms
    return nil unless started_at && completed_at
    ((completed_at - started_at) * 1000).to_i
  end

  def total_tokens
    return nil unless input_tokens && output_tokens
    input_tokens + output_tokens
  end

  def success?
    status == "completed" && error_message.blank?
  end

  def pending?
    status == "pending"
  end

  def in_progress?
    status == "in_progress"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def skipped?
    status == "skipped"
  end

  def next_stage
    llm_call.llm_stages.where("position > ?", position).order(position: :asc).first
  end

  def previous_stage
    llm_call.llm_stages.where("position < ?", position).order(position: :desc).first
  end

  def first?
    position == 0 || previous_stage.nil?
  end

  def last?
    next_stage.nil?
  end
end
