module LlmConfig
  module Provider
    class Ollama < Base
      class << self
        def provider_name
          "Ollama"
        end

        def provider_type
          "ollama"
        end

        def default_endpoint
          "http://localhost:11434"
        end

        def default_models
          %w[llama3.2 llama3.1 mistral codellama]
        end

        def requires_api_key?
          false
        end
      end

      def generate(prompt, schema: nil, timeout: 30, **opts)
        client = http_client(timeout: timeout)

        body = build_request_body(prompt, schema, opts)

        response = client.post("#{endpoint}/api/generate") do |req|
          req.headers["Content-Type"] = "application/json"
          req.headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
          req.body = body.to_json
        end

        handle_error_response(response) unless response.success?

        parse_response(response.body, schema: schema)
      end

      def available?
        client = http_client(timeout: 5)
        response = client.get("#{endpoint}/api/tags")
        response.success?
      rescue StandardError
        false
      end

      def list_models
        client = http_client(timeout: 10)
        response = client.get("#{endpoint}/api/tags")
        return [] unless response.success?

        data = parse_json_response(response.body)
        data["models"]&.map { |m| m["name"] } || []
      rescue StandardError
        []
      end

      private

      def build_request_body(prompt, schema, opts)
        body = {
          model: model,
          prompt: build_prompt(prompt, opts),
          stream: false,
          options: build_options(opts)
        }

        if schema
          body[:format] = "json"
          body[:prompt] = add_schema_instruction(body[:prompt], schema)
        end

        body
      end

      def build_prompt(prompt, opts)
        if opts[:system_prompt].present?
          "#{opts[:system_prompt]}\n\n#{prompt}"
        else
          prompt
        end
      end

      def build_options(opts)
        ollama_options = {}
        ollama_options[:temperature] = opts[:temperature] if opts[:temperature]
        ollama_options[:num_predict] = opts[:max_tokens] if opts[:max_tokens]

        options.merge(ollama_options.stringify_keys)
      end

      def add_schema_instruction(prompt, schema)
        <<~PROMPT
          #{prompt}

          You must respond with valid JSON matching this schema:
          #{schema.to_json}

          Respond only with the JSON, no other text.
        PROMPT
      end

      def parse_response(body, schema:)
        data = parse_json_response(body)
        content = data["response"]

        if schema && content.present?
          parse_json_response(content)
        else
          content
        end
      end
    end
  end
end
