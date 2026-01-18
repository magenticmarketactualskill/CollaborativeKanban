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
      schema_name = options[:schema]

      response = @connection.post("/v1/messages") do |req|
        req.headers["x-api-key"] = api_key
        req.headers["anthropic-version"] = API_VERSION
        req.body = build_request_body(prompt, model, schema_name, options)
      end

      latency = Time.current - start_time

      if response.success?
        content = extract_content(response.body, schema_name: schema_name)
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

    def build_request_body(prompt, model, schema_name, options)
      body = {
        model: model,
        max_tokens: options.fetch(:max_tokens, 1024),
        messages: build_messages(prompt, options),
        system: options[:system_prompt]
      }

      if schema_name
        schema = Llm::SchemaValidator.schema_for(schema_name)
        tool = build_tool_from_schema(schema_name, schema)
        body[:tools] = [tool]
        body[:tool_choice] = { type: "tool", name: tool[:name] }
      end

      body.compact
    end

    def build_tool_from_schema(schema_name, schema)
      {
        name: "respond_with_#{schema_name}",
        description: schema["description"] || "Respond with structured #{schema_name} data",
        input_schema: schema.except("$schema", "title", "description")
      }
    end

    def build_messages(prompt, options)
      messages = options.fetch(:messages, [])
      return messages if messages.any?

      [{ role: "user", content: prompt }]
    end

    def extract_content(body, schema_name: nil)
      content_blocks = body["content"] || []

      # If using tool_use, extract the JSON input from the tool call
      if schema_name
        tool_block = content_blocks.find { |block| block["type"] == "tool_use" }
        return tool_block["input"].to_json if tool_block
      end

      # Fall back to text content
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
