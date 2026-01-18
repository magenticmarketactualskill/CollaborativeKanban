# frozen_string_literal: true

module LlmClient
  module Providers
    REGISTRY = {
      "openai" => "LlmClient::Providers::Openai",
      "anthropic" => "LlmClient::Providers::Anthropic",
      "ollama" => "LlmClient::Providers::Ollama",
      "openrouter" => "LlmClient::Providers::Openrouter",
      "custom" => "LlmClient::Providers::Custom"
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
          provider_class = const_get_safe(class_name)
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

        klass = const_get_safe(class_name)
        raise ArgumentError, "Provider class not found: #{class_name}" unless klass

        klass
      end

      def const_get_safe(class_name)
        class_name.split("::").reduce(Object) { |mod, name| mod.const_get(name) }
      rescue NameError
        nil
      end
    end
  end
end
