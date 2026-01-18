# frozen_string_literal: true

module EntityKnowledge
  module Core
    module PredicateRegistry
      # Common predicates for software projects
      COMMON_PREDICATES = %w[
        owns
        manages
        created
        depends_on
        is_part_of
        relates_to
        blocks
        implements
        uses
        has_version
        has_status
        has_priority
        assigned_to
        reviewed_by
        deployed_to
        migrated_from
        integrates_with
      ].freeze

      INVERSE_PREDICATES = {
        "owns" => "owned_by",
        "owned_by" => "owns",
        "manages" => "managed_by",
        "managed_by" => "manages",
        "depends_on" => "depended_on_by",
        "depended_on_by" => "depends_on",
        "is_part_of" => "contains",
        "contains" => "is_part_of",
        "blocks" => "blocked_by",
        "blocked_by" => "blocks"
      }.freeze

      EXTRACTION_METHODS = %w[manual ai_llm ai_pattern inferred].freeze
      OBJECT_TYPES = %w[string date number boolean reference].freeze

      class << self
        def inverse_of(predicate)
          INVERSE_PREDICATES[predicate.to_s] || predicate.to_s
        end

        def common?(predicate)
          COMMON_PREDICATES.include?(predicate.to_s)
        end

        def all
          COMMON_PREDICATES
        end

        def valid_extraction_method?(method)
          EXTRACTION_METHODS.include?(method.to_s)
        end

        def valid_object_type?(type)
          OBJECT_TYPES.include?(type.to_s)
        end
      end
    end
  end
end
