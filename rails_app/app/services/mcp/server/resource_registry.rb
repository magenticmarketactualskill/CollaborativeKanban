module Mcp
  module Server
    class ResourceRegistry
      include Singleton

      def initialize
        @resources = {}
      end

      def register(resource)
        @resources[resource.uri_template] = resource
      end

      def list(config = nil)
        resources = @resources.values
        resources = resources.select { |r| config.resource_enabled?(r.name) } if config
        resources.map(&:to_definition)
      end

      def read(uri, context:)
        resource = find_matching_resource(uri)
        raise ResourceNotFoundError, uri unless resource
        resource.read(uri, context: context)
      end

      def clear!
        @resources = {}
      end

      def register_defaults!
        clear!
        register(Resources::CardSchema.new)
        register(Resources::BoardData.new)
        register(Resources::SkillDefinition.new)
      end

      private

      def find_matching_resource(uri)
        @resources.values.find { |r| r.matches?(uri) }
      end
    end

    class ResourceNotFoundError < StandardError; end
  end
end
