# frozen_string_literal: true

module LlmClient
  module Providers
    class Openai < Base
      class << self
        def provider_name
          "OpenAI"
        end

        def provider_type
          "openai"
        end

        def default_endpoint
          "https://api.openai.com/v1"
        end

        def default_models
          %w[gpt-4o gpt-4o-mini gpt-4-turbo gpt-3.5-turbo]
        end

        def requires_api_key?
          true
        end
      end

      def generate(prompt, schema: nil, timeout: 30, **opts)
        client = http_client(timeout: timeout)

        body = build_request_body(prompt, schema, opts)

        response = client.post("#{endpoint}/chat/completions") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["Authorization"] = "Bearer #{api_key}"
          req.body = body.to_json
        end

        handle_error_response(response) unless response.success?

        parse_response(response.body, schema: schema)
      end

      def available?
        return false unless present?(api_key)

        client = http_client(timeout: 10)
        response = client.get("#{endpoint}/models") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}"
        end

        response.success?
      rescue StandardError
        false
      end

      private

      def build_request_body(prompt, schema, opts)
        messages = build_messages(prompt, opts)

        body = {
          model: model,
          messages: messages,
          temperature: opts[:temperature] || options["temperature"] || 0.7,
          max_tokens: opts[:max_tokens] || options["max_tokens"] || 4096
        }

        if schema
          body[:response_format] = {
            type: "json_schema",
            json_schema: {
              name: "response",
              strict: true,
              schema: schema
            }
          }
        end

        body
      end

      def build_messages(prompt, opts)
        messages = []

        if present?(opts[:system_prompt])
          messages << { role: "system", content: opts[:system_prompt] }
        end

        messages << { role: "user", content: prompt }
        messages
      end

      def parse_response(body, schema:)
        data = parse_json_response(body)
        content = data.dig("choices", 0, "message", "content")

        if schema
          parse_json_response(content)
        else
          content
        end
      end
    end
  end
end
