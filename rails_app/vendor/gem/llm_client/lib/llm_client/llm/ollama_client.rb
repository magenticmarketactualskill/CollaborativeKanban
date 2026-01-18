# frozen_string_literal: true

module LlmClient
  module Llm
    class OllamaClient < BaseClient
      DEFAULT_MODEL = "llama3.2:3b"
      DEFAULT_HOST = "http://localhost:11434"

      def initialize(config = {})
        super
        @connection = build_connection(host)
      end

      def generate(prompt, **options)
        model = options.fetch(:model, config[:model])
        start_time = Time.now
        schema_name = options[:schema]

        response = @connection.post("/api/generate") do |req|
          req.body = build_request_body(prompt, model, schema_name, options)
        end

        latency = Time.now - start_time

        if response.success?
          wrap_response(
            response.body["response"],
            model: model,
            latency: latency
          )
        else
          raise InvalidResponseError, "Ollama returned #{response.status}"
        end
      rescue Faraday::ConnectionFailed => e
        error_response(ConnectionError.new("Cannot connect to Ollama: #{e.message}"), model: model)
      rescue Faraday::TimeoutError
        error_response(TimeoutError.new("Ollama request timed out"), model: model)
      end

      def available?
        response = @connection.get("/api/tags")
        response.success?
      rescue StandardError
        false
      end

      def name
        :ollama
      end

      def list_models
        response = @connection.get("/api/tags")
        return [] unless response.success?

        response.body["models"]&.map { |m| m["name"] } || []
      end

      private

      def build_request_body(prompt, model, schema_name, options)
        body = {
          model: model,
          prompt: prompt,
          stream: false,
          options: {
            temperature: options.fetch(:temperature, 0.1),
            num_predict: options.fetch(:max_tokens, 256)
          }
        }

        if schema_name
          schema = SchemaValidator.schema_for(schema_name)
          body[:format] = schema.reject { |k, _| %w[$schema title description].include?(k) }
        end

        body
      end

      def host
        config[:host] || LlmClient.configuration.ollama_host || DEFAULT_HOST
      end

      def default_config
        super.merge(
          timeout: 15,
          model: DEFAULT_MODEL
        )
      end
    end
  end
end
