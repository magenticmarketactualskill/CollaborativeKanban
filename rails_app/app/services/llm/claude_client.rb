# frozen_string_literal: true

module Llm
  class ClaudeClient < BaseClient
    API_URL = "https://api.anthropic.com"
    API_VERSION = "2023-06-01"
    DEFAULT_MODEL = "claude-3-5-haiku-20241022"

    def initialize(config = {})
      super
      @connection = build_connection(API_URL)
    end

    def generate(prompt, **options)
      model = options.fetch(:model, config[:model])
      start_time = Time.current

      response = @connection.post("/v1/messages") do |req|
        req.headers["x-api-key"] = api_key
        req.headers["anthropic-version"] = API_VERSION
        req.body = {
          model: model,
          max_tokens: options.fetch(:max_tokens, 1024),
          messages: build_messages(prompt, options),
          system: options[:system_prompt]
        }.compact
      end

      latency = Time.current - start_time

      if response.success?
        content = extract_content(response.body)
        wrap_response(content, model: model, latency: latency)
      elsif response.status == 429
        raise RateLimitError, "Claude API rate limit exceeded"
      else
        error_body = response.body
        raise InvalidResponseError, "Claude API error: #{error_body['error']&.dig('message') || response.status}"
      end
    rescue Faraday::ConnectionFailed => e
      error_response(ConnectionError.new("Cannot connect to Claude API: #{e.message}"), model: model)
    rescue Faraday::TimeoutError
      error_response(TimeoutError.new("Claude API request timed out"), model: model)
    rescue RateLimitError => e
      error_response(e, model: model)
    end

    def available?
      api_key.present?
    end

    def name
      :claude
    end

    private

    def api_key
      config[:api_key] || Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]
    end

    def build_messages(prompt, options)
      messages = options.fetch(:messages, [])
      return messages if messages.any?

      [{ role: "user", content: prompt }]
    end

    def extract_content(body)
      content_blocks = body["content"] || []
      content_blocks.map { |block| block["text"] if block["type"] == "text" }.compact.join
    end

    def default_config
      super.merge(
        timeout: 60,
        model: DEFAULT_MODEL
      )
    end
  end
end
