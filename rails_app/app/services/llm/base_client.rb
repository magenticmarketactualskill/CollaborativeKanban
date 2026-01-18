# frozen_string_literal: true

module Llm
  class BaseClient
    class Error < StandardError; end
    class ConnectionError < Error; end
    class TimeoutError < Error; end
    class RateLimitError < Error; end
    class InvalidResponseError < Error; end

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
      Llm::Response.new(
        content: raw_response,
        model: model,
        provider: name,
        latency: latency,
        success: true
      )
    end

    def error_response(error, model:)
      Llm::Response.new(
        content: nil,
        model: model,
        provider: name,
        error: error.message,
        success: false
      )
    end
  end
end
