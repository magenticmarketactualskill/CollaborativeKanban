# frozen_string_literal: true

require "faraday"
require "faraday/retry"

module LlmClient
  module Llm
    class BaseClient
      DEFAULT_TIMEOUT = 30

      attr_reader :config

      def initialize(config = {})
        @config = default_config.merge(config)
      end

      def generate(prompt, **options)
        raise NotImplementedError, "#{self.class} must implement #generate"
      end

      def available?
        raise NotImplementedError, "#{self.class} must implement #available?"
      end

      def name
        raise NotImplementedError, "#{self.class} must implement #name"
      end

      protected

      def default_config
        {
          timeout: DEFAULT_TIMEOUT,
          max_retries: 3,
          retry_delay: 1
        }
      end

      def build_connection(base_url)
        Faraday.new(url: base_url) do |conn|
          conn.request :json
          conn.response :json
          conn.request :retry, {
            max: config[:max_retries],
            interval: config[:retry_delay],
            exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed]
          }
          conn.options.timeout = config[:timeout]
          conn.options.open_timeout = 10
        end
      end

      def wrap_response(raw_response, model:, latency:)
        Response.new(
          content: raw_response,
          model: model,
          provider: name,
          latency: latency,
          success: true
        )
      end

      def error_response(error, model:)
        Response.new(
          content: nil,
          model: model,
          provider: name,
          error: error.message,
          success: false
        )
      end
    end
  end
end
