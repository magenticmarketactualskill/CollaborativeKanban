# frozen_string_literal: true

module LlmClient
  module Providers
    class Openrouter < Base
      class << self
        def provider_name
          "OpenRouter"
        end

        def provider_type
          "openrouter"
        end

        def default_endpoint
          "https://openrouter.ai/api/v1"
        end

        def default_models
          %w[anthropic/claude-3.5-sonnet openai/gpt-4o meta-llama/llama-3.1-70b-instruct]
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
          req.headers["HTTP-Referer"] = opts[:referer] || options["referer"] || ""
          req.headers["X-Title"] = opts[:app_name] || options["app_name"] || "LlmClient"
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
          body[:response_format] = { type: "json_object" }
          messages.last[:content] = add_schema_instruction(messages.last[:content], schema)
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

      def add_schema_instruction(prompt, schema)
        <<~PROMPT
          #{prompt}

          Respond with valid JSON matching this schema:
          #{schema.to_json}
        PROMPT
      end

      def parse_response(body, schema:)
        data = parse_json_response(body)
        content = data.dig("choices", 0, "message", "content")

        if schema && present?(content)
          parse_json_response(content)
        else
          content
        end
      end
    end
  end
end
