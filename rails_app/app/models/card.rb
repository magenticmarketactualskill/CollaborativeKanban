class Card < ApplicationRecord
  PRIORITIES = %w[low medium high urgent].freeze
  CARD_TYPES = %w[task checklist bug milestone].freeze

  belongs_to :board
  belongs_to :column
  belongs_to :created_by, class_name: 'User'
  has_many :card_assignments, dependent: :destroy
  has_many :assignees, through: :card_assignments, source: :user
  has_many :ai_suggestions, dependent: :destroy

  validates :title, presence: true
  validates :priority, inclusion: { in: PRIORITIES }
  validates :position, numericality: { greater_than_or_equal_to: 0 }
  validates :card_type, inclusion: { in: CARD_TYPES }, allow_nil: true

  before_create :set_position
  after_create_commit :infer_card_type_async, if: :should_infer_type?

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

  # Schema and ViewComponent methods
  def schema
    CardSchemas::Registry.instance.schema_for_card(self)
  end

  def component_class
    schema&.component_class || Cards::TaskCardComponent
  end

  def render_component(board:)
    component_class.new(card: self, board: board)
  end

  # AI-related methods
  def infer_type!
    inferrer = CardIntelligence::TypeInferrer.new
    result = inferrer.infer(title: title, description: description)

    update!(
      card_type: result.type,
      type_inference_confidence: result.confidence.to_s,
      type_inferred_at: Time.current
    )

    result
  end

  def analyze!
    analyzer = CardIntelligence::ContentAnalyzer.new
    result = analyzer.analyze(self)

    if result.success?
      update!(
        ai_summary: result.summary,
        ai_analyzed_at: Time.current
      )
    end

    result
  end

  def generate_suggestions!
    generator = CardIntelligence::SuggestionGenerator.new
    suggestions = generator.generate(self)

    ai_suggestions.pending.destroy_all
    suggestions.each(&:save!)

    suggestions
  end

  def pending_suggestions
    ai_suggestions.pending
  end

  def has_pending_suggestions?
    ai_suggestions.pending.exists?
  end

  private

  def set_position
    self.position ||= column.cards.maximum(:position).to_i + 1
  end

  def should_infer_type?
    Rails.application.config.llm.auto_infer_type &&
      card_type == "task" &&
      type_inferred_at.nil?
  end

  def infer_card_type_async
    CardTypeInferenceJob.perform_later(id)
  end
end
