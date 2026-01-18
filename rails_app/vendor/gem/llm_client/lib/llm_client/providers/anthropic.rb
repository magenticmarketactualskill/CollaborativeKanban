# frozen_string_literal: true

module LlmClient
  module Providers
    class Anthropic < Base
      ANTHROPIC_VERSION = "2023-06-01"

      class << self
        def provider_name
          "Anthropic"
        end

        def provider_type
          "anthropic"
        end

        def default_endpoint
          "https://api.anthropic.com/v1"
        end

        def default_models
          %w[claude-3-5-sonnet-20241022 claude-3-5-haiku-20241022 claude-3-opus-20240229]
        end

        def requires_api_key?
          true
        end
      end

      def generate(prompt, schema: nil, timeout: 30, **opts)
        client = http_client(timeout: timeout)

        body = build_request_body(prompt, schema, opts)

        response = client.post("#{endpoint}/messages") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["x-api-key"] = api_key
          req.headers["anthropic-version"] = ANTHROPIC_VERSION
          req.body = body.to_json
        end

        handle_error_response(response) unless response.success?

        parse_response(response.body, schema: schema)
      end

      def available?
        return false unless present?(api_key)

        client = http_client(timeout: 10)
        response = client.post("#{endpoint}/messages") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["x-api-key"] = api_key
          req.headers["anthropic-version"] = ANTHROPIC_VERSION
          req.body = {
            model: model,
            max_tokens: 10,
            messages: [{ role: "user", content: "Hi" }]
          }.to_json
        end

        response.success?
      rescue StandardError
        false
      end

      private

      def build_request_body(prompt, schema, opts)
        body = {
          model: model,
          max_tokens: opts[:max_tokens] || options["max_tokens"] || 4096,
          messages: build_messages(prompt, opts)
        }

        if present?(opts[:system_prompt])
          body[:system] = opts[:system_prompt]
        end

        if schema
          body[:tools] = build_tool_for_schema(schema)
          body[:tool_choice] = { type: "tool", name: "structured_response" }
        end

        body
      end

      def build_messages(prompt, opts)
        [{ role: "user", content: prompt }]
      end

      def build_tool_for_schema(schema)
        [{
          name: "structured_response",
          description: "Return a structured response matching the schema",
          input_schema: schema
        }]
      end

      def parse_response(body, schema:)
        data = parse_json_response(body)

        if schema
          tool_use = data.dig("content")&.find { |c| c["type"] == "tool_use" }
          tool_use&.dig("input") || extract_text_content(data)
        else
          extract_text_content(data)
        end
      end

      def extract_text_content(data)
        text_block = data.dig("content")&.find { |c| c["type"] == "text" }
        text_block&.dig("text") || ""
      end
    end
  end
end
