# frozen_string_literal: true

module CardIntelligence
  class PatternExtractor
    # Card-aware wrapper around EntityKnowledge::Extraction::PatternExtractor.
    # Extracts entities and facts from card content using pattern matching.

    def initialize
      @extractor = EntityKnowledge::Extraction::PatternExtractor.new
    end

    def extract(card)
      results = { entities: [], facts: [] }

      text_fields = [
        { field: "title", text: card.title },
        { field: "description", text: card.description }
      ].compact_blank

      text_fields.each do |field_info|
        next if field_info[:text].blank?

        result = @extractor.extract(field_info[:text], source_field: field_info[:field])
        results[:entities].concat(result[:entities])
        results[:facts].concat(result[:facts])
      end

      { entities: results[:entities].uniq { |e| e[:name].downcase }, facts: results[:facts] }
    end
  end
end
