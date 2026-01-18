# frozen_string_literal: true

module EntityKnowledge
  module Extraction
    class PatternExtractor
      # Pattern-based extraction for common structures.
      # Fast and high precision, but limited coverage.
      #
      # Usage:
      #   extractor = EntityKnowledge::Extraction::PatternExtractor.new
      #   result = extractor.extract("Fix auth bug for @john")
      #   # => { entities: [...], facts: [...] }

      def initialize(patterns: Patterns::PATTERNS)
        @patterns = patterns
      end

      def extract(text, source_field: "content")
        return { entities: [], facts: [] } if text.blank?

        entities = []
        facts = []

        @patterns.each do |pattern_name, config|
          extract_pattern(text, source_field, pattern_name, config, entities, facts)
        end

        { entities: entities.uniq { |e| e[:name].downcase }, facts: facts }
      end

      private

      def extract_pattern(text, source_field, pattern_name, config, entities, facts)
        text.scan(config[:regex]) do |match|
          value = match.is_a?(Array) ? match.first : match
          next if value.blank?

          offset = Regexp.last_match.begin(0)

          if config[:entity_type]
            entities << build_entity(value, config, source_field, offset)
          end

          if config[:fact_predicate]
            facts << build_fact(value, config, source_field)
          end
        end
      end

      def build_entity(value, config, source_field, offset)
        {
          name: normalize_name(value, config[:entity_type]),
          entity_type: config[:entity_type],
          confidence: config[:confidence],
          extraction_method: "ai_pattern",
          source_field: source_field,
          offset_start: offset,
          offset_end: offset + value.length
        }
      end

      def build_fact(value, config, source_field)
        {
          predicate: config[:fact_predicate],
          object_name: normalize_value(value, config[:fact_predicate]),
          object_is_entity: Patterns.entity_object_predicate?(config[:fact_predicate]),
          confidence: config[:confidence],
          extraction_method: "ai_pattern",
          source_field: source_field
        }
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
    end
  end
end
