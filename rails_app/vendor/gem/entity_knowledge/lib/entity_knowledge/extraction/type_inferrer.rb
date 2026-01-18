# frozen_string_literal: true

module EntityKnowledge
  module Extraction
    module TypeInferrer
      class << self
        def infer(name)
          return "person" if person_name?(name)
          return "system" if system_name?(name)
          return "artifact" if artifact_name?(name)
          return "event" if event_name?(name)

          "concept"
        end

        private

        def person_name?(name)
          # Matches "John Smith", "Sarah Chen", etc.
          name.match?(/^[A-Z][a-z]+ [A-Z][a-z]+$/)
        end

        def system_name?(name)
          name.match?(/service|api|server|database/i)
        end

        def artifact_name?(name)
          name.match?(/controller|model|component|module/i)
        end

        def event_name?(name)
          name.match?(/sprint|release|meeting|review/i)
        end
      end
    end
  end
end
