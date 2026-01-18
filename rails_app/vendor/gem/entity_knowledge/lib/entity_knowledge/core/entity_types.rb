# frozen_string_literal: true

module EntityKnowledge
  module Core
    module EntityTypes
      ENTITY_TYPES = %w[
        person
        system
        concept
        location
        organization
        artifact
        event
        metric
      ].freeze

      ICONS = {
        "person" => "user",
        "system" => "server",
        "concept" => "lightbulb",
        "location" => "map-pin",
        "organization" => "building",
        "artifact" => "file-code",
        "event" => "calendar",
        "metric" => "chart-bar"
      }.freeze

      DEFAULT_ICON = "circle"

      class << self
        def valid?(type)
          ENTITY_TYPES.include?(type.to_s)
        end

        def icon_for(type)
          ICONS[type.to_s] || DEFAULT_ICON
        end

        def all
          ENTITY_TYPES
        end
      end
    end
  end
end
