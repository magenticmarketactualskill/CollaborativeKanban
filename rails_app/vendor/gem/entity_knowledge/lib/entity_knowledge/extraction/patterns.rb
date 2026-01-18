# frozen_string_literal: true

module EntityKnowledge
  module Extraction
    module Patterns
      # Pattern definitions for entity and fact extraction
      PATTERNS = {
        # @mentions
        mention: {
          regex: /@(\w+)/,
          entity_type: "person",
          confidence: 0.9
        },
        # Assignee patterns
        assigned_to: {
          regex: /(?:assigned to|owner:|lead:)\s*(\w+(?:\s+\w+)?)/i,
          entity_type: "person",
          confidence: 0.85
        },
        # Version numbers
        version: {
          regex: /v?(\d+\.\d+(?:\.\d+)?)/,
          fact_predicate: "has_version",
          confidence: 0.95
        },
        # URLs
        url: {
          regex: %r{https?://[^\s<>"{}|\\^`\[\]]+},
          entity_type: "artifact",
          confidence: 0.95
        },
        # GitHub/Jira references
        issue_ref: {
          regex: /(?:#|[A-Z]+-)\d+/,
          entity_type: "artifact",
          confidence: 0.9
        },
        # Service/API names
        service: {
          regex: /(?:(\w+)[-_]?(?:service|api|server|db|database|cache))/i,
          entity_type: "system",
          confidence: 0.8
        },
        # Component names
        component: {
          regex: /(?:(\w+)(?:Controller|Model|View|Component|Module|Service|Helper|Job|Worker))/,
          entity_type: "artifact",
          confidence: 0.85
        },
        # Due dates
        due_date: {
          regex: /(?:due|deadline|by):\s*(\d{4}-\d{2}-\d{2}|\d{1,2}\/\d{1,2}\/\d{2,4})/i,
          fact_predicate: "has_deadline",
          confidence: 0.9
        },
        # Dependencies
        depends_on: {
          regex: /(?:depends on|requires|needs|blocked by)\s+["']?([^"'\n,]+)["']?/i,
          fact_predicate: "depends_on",
          confidence: 0.8
        },
        # Blocks
        blocks: {
          regex: /(?:blocks|blocking)\s+["']?([^"'\n,]+)["']?/i,
          fact_predicate: "blocks",
          confidence: 0.8
        }
      }.freeze

      # Predicates that have entity objects (vs literal values)
      ENTITY_OBJECT_PREDICATES = %w[depends_on blocks assigned_to owned_by].freeze

      class << self
        def all
          PATTERNS
        end

        def entity_patterns
          PATTERNS.select { |_, config| config[:entity_type] }
        end

        def fact_patterns
          PATTERNS.select { |_, config| config[:fact_predicate] }
        end

        def entity_object_predicate?(predicate)
          ENTITY_OBJECT_PREDICATES.include?(predicate.to_s)
        end
      end
    end
  end
end
