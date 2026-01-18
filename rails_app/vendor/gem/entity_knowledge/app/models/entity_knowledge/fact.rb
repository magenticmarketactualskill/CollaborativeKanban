# frozen_string_literal: true

module EntityKnowledge
  class Fact < ApplicationRecord
    # A structured assertion about entities or their relationships.
    # Facts follow subject-predicate-object (triple) structure.
    #
    # Entity-to-Entity facts:
    #   - "Auth Service" -[depends_on]-> "Database"
    #   - "John" -[owns]-> "Payment Module"
    #
    # Entity-to-Value facts:
    #   - "Payment Service" -[version]-> "2.0.1"
    #   - "Sprint 5" -[end_date]-> "2024-02-15"

    self.table_name = "facts"

    EXTRACTION_METHODS = Core::PredicateRegistry::EXTRACTION_METHODS
    OBJECT_TYPES = Core::PredicateRegistry::OBJECT_TYPES
    COMMON_PREDICATES = Core::PredicateRegistry::COMMON_PREDICATES
    INVERSE_PREDICATES = Core::PredicateRegistry::INVERSE_PREDICATES

    belongs_to :subject_entity, class_name: "EntityKnowledge::Entity"
    belongs_to :object_entity, class_name: "EntityKnowledge::Entity", optional: true
    belongs_to :domain, class_name: "EntityKnowledge::Domain"

    validates :predicate, presence: true, length: { maximum: 100 }
    validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
    validates :extraction_method, inclusion: { in: EXTRACTION_METHODS }, allow_nil: true
    validates :object_type, inclusion: { in: OBJECT_TYPES }, allow_nil: true
    validate :must_have_object_entity_or_value

    scope :entity_to_entity, -> { where.not(object_entity_id: nil) }
    scope :entity_to_value, -> { where(object_entity_id: nil) }
    scope :with_predicate, ->(pred) { where(predicate: pred) }
    scope :high_confidence, -> { where("confidence >= ?", 0.8) }
    scope :ai_extracted, -> { where(extraction_method: %w[ai_llm ai_pattern]) }
    scope :current, -> { where(valid_until: nil) }
    scope :historical, -> { where.not(valid_until: nil) }
    scope :affirmative, -> { where(negated: false) }
    scope :negated_facts, -> { where(negated: true) }

    def self.between_entities(entity1, entity2)
      where(subject_entity_id: entity1.id, object_entity_id: entity2.id)
        .or(where(subject_entity_id: entity2.id, object_entity_id: entity1.id))
    end

    def entity_to_entity?
      object_entity_id.present?
    end

    def entity_to_value?
      object_entity_id.blank? && object_value.present?
    end

    def object
      entity_to_entity? ? object_entity : typed_object_value
    end

    def typed_object_value
      return nil unless object_value

      case object_type
      when "date" then Date.parse(object_value) rescue object_value
      when "number" then object_value.to_f
      when "boolean" then object_value.downcase == "true"
      else object_value
      end
    end

    def to_sentence
      obj = entity_to_entity? ? object_entity.name : "\"#{object_value}\""
      negation = negated? ? " NOT" : ""
      "#{subject_entity.name}#{negation} #{predicate} #{obj}"
    end

    def to_triple
      {
        subject: subject_entity.name,
        predicate: predicate,
        object: entity_to_entity? ? object_entity.name : object_value,
        object_type: entity_to_entity? ? "entity" : object_type
      }
    end

    def inverse
      return nil unless entity_to_entity?

      self.class.find_by(
        subject_entity_id: object_entity_id,
        object_entity_id: subject_entity_id,
        predicate: inverse_predicate
      )
    end

    def inverse_predicate
      Core::PredicateRegistry.inverse_of(predicate)
    end

    def expire!(at: Time.current)
      update!(valid_until: at)
    end

    def ai_extracted?
      %w[ai_llm ai_pattern].include?(extraction_method)
    end

    def needs_review?
      ai_extracted? && confidence < 0.8
    end

    private

    def must_have_object_entity_or_value
      if object_entity_id.blank? && object_value.blank?
        errors.add(:base, "must have either object_entity or object_value")
      end
      if object_entity_id.present? && object_value.present?
        errors.add(:base, "cannot have both object_entity and object_value")
      end
    end
  end
end
