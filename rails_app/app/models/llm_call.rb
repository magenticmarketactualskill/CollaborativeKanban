class LlmCall < ApplicationRecord
  STATUSES = %w[pending in_progress completed failed].freeze
  TASK_TYPES = %w[
    type_inference classification extraction
    analysis suggestion schema_generation
    summarization relationship_detection
    custom
  ].freeze

  belongs_to :llm_configuration
  has_many :llm_stages, -> { order(position: :asc) }, dependent: :destroy

  validates :task_type, presence: true, inclusion: { in: TASK_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :for_task, ->(task_type) { where(task_type: task_type) }
  scope :for_provider, ->(provider) { where(provider: provider) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_configuration, ->(config_id) { where(llm_configuration_id: config_id) }

  before_create :set_started_at

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

  def add_stage(name:, stage_type: nil, **attributes)
    next_position = llm_stages.maximum(:position).to_i + 1
    llm_stages.create!(
      name: name,
      stage_type: stage_type,
      position: next_position,
      **attributes
    )
  end

  def current_stage
    llm_stages.where(status: "in_progress").first || llm_stages.where(status: "pending").first
  end

  def last_completed_stage
    llm_stages.where(status: "completed").order(position: :desc).first
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end
end
