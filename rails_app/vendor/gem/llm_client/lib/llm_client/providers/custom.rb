# frozen_string_literal: true

module LlmClient
  module Providers
    class Custom < Base
      class << self
        def provider_name
          "Custom (OpenAI-compatible)"
        end

        def provider_type
          "custom"
        end

        def default_endpoint
          ""
        end

        def default_models
          []
        end

        def requires_api_key?
          false
        end
      end

      def generate(prompt, schema: nil, timeout: 30, **opts)
        client = http_client(timeout: timeout)

        body = build_request_body(prompt, schema, opts)
        completions_endpoint = options["completions_path"] || "/chat/completions"

        response = client.post("#{endpoint}#{completions_endpoint}") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["Authorization"] = "Bearer #{api_key}" if present?(api_key)

          options["headers"]&.each do |key, value|
            req.headers[key] = value
          end

          req.body = body.to_json
        end

        handle_error_response(response) unless response.success?

        parse_response(response.body, schema: schema)
      end

      def available?
        return false unless present?(endpoint)

        client = http_client(timeout: 10)
        health_endpoint = options["health_path"] || "/models"

        response = client.get("#{endpoint}#{health_endpoint}") do |req|
          req.headers["Authorization"] = "Bearer #{api_key}" if present?(api_key)
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
          if options["json_schema_support"]
            body[:response_format] = {
              type: "json_schema",
              json_schema: {
                name: "response",
                strict: true,
                schema: schema
              }
            }
          else
            body[:response_format] = { type: "json_object" }
            messages.last[:content] = add_schema_instruction(messages.last[:content], schema)
          end
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
