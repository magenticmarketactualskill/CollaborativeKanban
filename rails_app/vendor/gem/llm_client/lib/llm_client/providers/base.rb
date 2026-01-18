# frozen_string_literal: true

require "faraday"
require "json"

module LlmClient
  module Providers
    class Base
      class ConnectionError < LlmClient::Error; end
      class TimeoutError < LlmClient::Error; end
      class RateLimitError < LlmClient::Error; end
      class AuthenticationError < LlmClient::Error; end
      class InvalidResponseError < LlmClient::Error; end

      attr_reader :configuration

      # configuration: Object that responds to provider_type, model, api_key, endpoint, options, name
      def initialize(configuration)
        @configuration = configuration
      end

      def generate(prompt, schema: nil, timeout: nil, **options)
        raise NotImplementedError, "#{self.class}#generate must be implemented"
      end

      def available?
        raise NotImplementedError, "#{self.class}#available? must be implemented"
      end

      def test_connection
        if available?
          { success: true, message: "Connected to #{name}" }
        else
          { success: false, message: "Unable to connect to #{name}" }
        end
      rescue StandardError => e
        { success: false, message: "Error: #{e.message}" }
      end

      def name
        config_name = configuration.respond_to?(:name) ? configuration.name : "default"
        "#{self.class.provider_name} (#{config_name})"
      end

      def endpoint
        if configuration.respond_to?(:effective_endpoint)
          configuration.effective_endpoint
        elsif configuration.respond_to?(:endpoint)
          ep = configuration.endpoint
          present?(ep) ? ep : self.class.default_endpoint
        else
          self.class.default_endpoint
        end
      end

      def model
        configuration.respond_to?(:model) ? configuration.model : nil
      end

      def api_key
        configuration.respond_to?(:api_key) ? configuration.api_key : nil
      end

      def options
        if configuration.respond_to?(:options)
          configuration.options || {}
        else
          {}
        end
      end

      class << self
        def provider_name
          raise NotImplementedError, "#{self}.provider_name must be implemented"
        end

        def provider_type
          raise NotImplementedError, "#{self}.provider_type must be implemented"
        end

        def default_endpoint
          raise NotImplementedError, "#{self}.default_endpoint must be implemented"
        end

        def default_models
          []
        end

        def requires_api_key?
          true
        end
      end

      protected

      def http_client(timeout: 30)
        Faraday.new do |f|
          f.options.timeout = timeout
          f.options.open_timeout = 10
          f.request :retry, max: 2, interval: 0.5, backoff_factor: 2
          f.adapter Faraday.default_adapter
        end
      end

      def parse_json_response(body)
        JSON.parse(body)
      rescue JSON::ParserError => e
        raise InvalidResponseError, "Invalid JSON response: #{e.message}"
      end

      def handle_error_response(response)
        case response.status
        when 401
          raise AuthenticationError, "Invalid API key or unauthorized"
        when 429
          raise RateLimitError, "Rate limit exceeded"
        when 408, 504
          raise TimeoutError, "Request timed out"
        else
          raise ConnectionError, "HTTP #{response.status}: #{response.body}"
        end
      end

      def present?(value)
        case value
        when nil then false
        when String then !value.empty?
        else true
        end
      end
    end
  end
end
