# frozen_string_literal: true

module EntityKnowledge
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ExtractionError < Error; end
  class InvalidEntityTypeError < Error; end
  class InvalidPredicateError < Error; end
end
