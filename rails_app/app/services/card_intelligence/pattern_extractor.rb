# frozen_string_literal: true

module CardIntelligence
  class PatternExtractor
    # Pattern-based extraction for common structures.
    # Fast and high precision, but limited coverage.
    #
    # Extracts:
    # - People names (e.g., "@john", "assigned to Jane")
    # - URLs and external references
    # - Version numbers
    # - Dates and deadlines
    # - Technical terms (APIs, services, etc.)

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

    def extract(card)
      entities = []
      facts = []

      text_fields = [
        { field: "title", text: card.title },
        { field: "description", text: card.description }
      ].compact_blank

      text_fields.each do |field_info|
        field = field_info[:field]
        text = field_info[:text]
        next if text.blank?

        PATTERNS.each do |pattern_name, config|
          extract_pattern(text, field, pattern_name, config, entities, facts)
        end
      end

      { entities: entities.uniq { |e| e[:name].downcase }, facts: facts }
    end

    private

    def extract_pattern(text, field, pattern_name, config, entities, facts)
      text.scan(config[:regex]) do |match|
        value = match.is_a?(Array) ? match.first : match
        next if value.blank?

        offset = Regexp.last_match.begin(0)

        if config[:entity_type]
          entities << {
            name: normalize_name(value, config[:entity_type]),
            entity_type: config[:entity_type],
            confidence: config[:confidence],
            extraction_method: "ai_pattern",
            source_field: field,
            offset_start: offset,
            offset_end: offset + value.length
          }
        end

        if config[:fact_predicate]
          facts << {
            predicate: config[:fact_predicate],
            object_name: normalize_value(value, config[:fact_predicate]),
            object_is_entity: fact_object_is_entity?(config[:fact_predicate]),
            confidence: config[:confidence],
            extraction_method: "ai_pattern",
            source_field: field
          }
        end
      end
    end

    def normalize_name(value, entity_type)
      case entity_type
      when "person"
        value.strip.gsub(/^@/, "").titleize
      when "system"
        value.strip.gsub(/[-_]/, " ").titleize
      else
        value.strip
      end
    end

    def normalize_value(value, predicate)
      case predicate
      when "has_version"
        value.gsub(/^v/i, "")
      when "has_deadline"
        parse_date(value)&.to_s || value
      else
        value.strip
      end
    end

    def parse_date(value)
      Date.parse(value)
    rescue ArgumentError
      nil
    end

    def fact_object_is_entity?(predicate)
      %w[depends_on blocks assigned_to owned_by].include?(predicate)
    end
  end
end
