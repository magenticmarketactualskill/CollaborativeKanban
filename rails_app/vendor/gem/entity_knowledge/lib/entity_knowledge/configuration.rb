# frozen_string_literal: true

module EntityKnowledge
  class Configuration
    attr_accessor :fuzzy_threshold, :min_token_length, :default_confidence

    def initialize
      @fuzzy_threshold = 0.8
      @min_token_length = 3
      @default_confidence = 0.8
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end
