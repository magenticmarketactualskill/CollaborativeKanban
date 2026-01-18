class Card < ApplicationRecord
  PRIORITIES = %w[low medium high urgent].freeze
  CARD_TYPES = %w[task checklist bug milestone].freeze

  belongs_to :board
  belongs_to :column
  belongs_to :created_by, class_name: 'User'
  has_many :card_assignments, dependent: :destroy
  has_many :assignees, through: :card_assignments, source: :user
  has_many :ai_suggestions, dependent: :destroy

  # Card relationships
  has_many :outgoing_relationships,
           class_name: 'CardRelationship',
           foreign_key: :source_card_id,
           dependent: :destroy
  has_many :incoming_relationships,
           class_name: 'CardRelationship',
           foreign_key: :target_card_id,
           dependent: :destroy

  # Knowledge graph associations
  has_many :card_facts, dependent: :destroy
  has_many :facts, through: :card_facts
  has_many :entity_mentions, dependent: :destroy
  has_many :mentioned_entities, through: :entity_mentions, source: :entity

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

  # Relationship query methods
  def blocks
    Card.joins(:incoming_relationships)
        .where(card_relationships: { source_card_id: id, relationship_type: 'blocks' })
  end

  def blocked_by
    Card.joins(:outgoing_relationships)
        .where(card_relationships: { target_card_id: id, relationship_type: 'blocks' })
  end

  def depends_on
    Card.joins(:incoming_relationships)
        .where(card_relationships: { source_card_id: id, relationship_type: 'depends_on' })
  end

  def dependencies
    Card.joins(:outgoing_relationships)
        .where(card_relationships: { target_card_id: id, relationship_type: 'depends_on' })
  end

  def related_cards
    outgoing_ids = outgoing_relationships.related.pluck(:target_card_id)
    incoming_ids = incoming_relationships.related.pluck(:source_card_id)
    Card.where(id: (outgoing_ids + incoming_ids).uniq)
  end

  def all_relationships
    outgoing_relationships + incoming_relationships
  end

  def has_blockers?
    blocked_by.exists?
  end

  def blocking_status
    return :blocked if has_blockers?
    return :blocking if blocks.exists?
    :clear
  end

  def generate_relationship_suggestions!
    detector = CardIntelligence::RelationshipDetector.new
    suggestions = detector.detect(self)

    ai_suggestions.pending.where(suggestion_type: 'add_relationship').destroy_all
    suggestions.each(&:save!)

    suggestions
  end

  # Knowledge graph extraction
  def extract_knowledge!
    extractor = CardIntelligence::KnowledgeExtractor.new
    extractor.extract(self)
  end

  def extract_knowledge_async
    KnowledgeExtractionJob.perform_later(id)
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
