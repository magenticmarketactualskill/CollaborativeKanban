# frozen_string_literal: true

require_relative "entity_knowledge/version"
require_relative "entity_knowledge/errors"
require_relative "entity_knowledge/configuration"

# Core constants
require_relative "entity_knowledge/core/entity_types"
require_relative "entity_knowledge/core/predicate_registry"

# Extraction services
require_relative "entity_knowledge/extraction/patterns"
require_relative "entity_knowledge/extraction/type_inferrer"
require_relative "entity_knowledge/extraction/pattern_extractor"
require_relative "entity_knowledge/extraction/entity_linker"

# Rails Engine
require_relative "entity_knowledge/engine" if defined?(Rails)

module EntityKnowledge
  class << self
    # Convenience method for pattern extraction
    def extract_patterns(text, source_field: "content")
      Extraction::PatternExtractor.new.extract(text, source_field: source_field)
    end

    # Convenience method for entity linking
    def link_entities(text, entities, source_field: "content")
      Extraction::EntityLinker.new.link(text, entities, source_field: source_field)
    end

    # Convenience method for type inference
    def infer_type(name)
      Extraction::TypeInferrer.infer(name)
    end
  end
end
