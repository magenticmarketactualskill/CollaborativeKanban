module LlmConfig
  module Provider
    REGISTRY = {
      "openai" => "LlmConfig::Provider::Openai",
      "anthropic" => "LlmConfig::Provider::Anthropic",
      "ollama" => "LlmConfig::Provider::Ollama",
      "openrouter" => "LlmConfig::Provider::Openrouter",
      "custom" => "LlmConfig::Provider::Custom"
    }.freeze

    class << self
      def for(configuration)
        provider_class = find_provider_class(configuration.provider_type)
        provider_class.new(configuration)
      end

      def registered_types
        REGISTRY.keys
      end

      def provider_class_for(type)
        find_provider_class(type)
      end

      def all_providers
        REGISTRY.map do |type, class_name|
          provider_class = class_name.safe_constantize
          next unless provider_class

          {
            type: type,
            name: provider_class.provider_name,
            default_endpoint: provider_class.default_endpoint,
            default_models: provider_class.default_models,
            requires_api_key: provider_class.requires_api_key?
          }
        end.compact
      end

      private

      def find_provider_class(type)
        class_name = REGISTRY[type.to_s]
        raise ArgumentError, "Unknown provider type: #{type}" unless class_name

        klass = class_name.safe_constantize
        raise ArgumentError, "Provider class not found: #{class_name}" unless klass

        klass
      end
    end
  end
end
