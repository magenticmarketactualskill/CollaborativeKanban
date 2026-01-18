# frozen_string_literal: true

module Llm
  class Router
    # Task categories and their preferred providers
    ROUTING_TABLE = {
      # Fast, simple tasks -> Ollama (local)
      type_inference: { primary: :ollama, fallback: :claude, timeout: 10 },
      classification: { primary: :ollama, fallback: :claude, timeout: 10 },
      extraction: { primary: :ollama, fallback: :claude, timeout: 15 },

      # Complex reasoning tasks -> Claude
      analysis: { primary: :claude, fallback: :ollama, timeout: 45 },
      suggestion: { primary: :claude, fallback: :ollama, timeout: 45 },
      schema_generation: { primary: :claude, fallback: nil, timeout: 60 },
      summarization: { primary: :claude, fallback: :ollama, timeout: 30 }
    }.freeze

    class << self
      def route(task, prompt, **options)
        routing = ROUTING_TABLE.fetch(task) do
          raise ArgumentError, "Unknown task type: #{task}"
        end

        client = client_for(routing[:primary])
        fallback_client = routing[:fallback] ? client_for(routing[:fallback]) : nil

        execute_with_fallback(
          client: client,
          fallback_client: fallback_client,
          prompt: prompt,
          timeout: routing[:timeout],
          **options
        )
      end

      def client_for(provider)
        case provider
        when :ollama then ollama_client
        when :claude then claude_client
        else raise ArgumentError, "Unknown provider: #{provider}"
        end
      end

      def ollama_client
        @ollama_client ||= OllamaClient.new
      end

      def claude_client
        @claude_client ||= ClaudeClient.new
      end

      def ollama_available?
        ollama_client.available?
      end

      def claude_available?
        claude_client.available?
      end

      def reset_clients!
        @ollama_client = nil
        @claude_client = nil
      end

      private

      def execute_with_fallback(client:, fallback_client:, prompt:, timeout:, **options)
        return fallback_response unless client.available?

        response = client.generate(prompt, timeout: timeout, **options)

        if response.success?
          response
        elsif fallback_client&.available?
          Rails.logger.warn("LLM Router: Falling back from #{client.name} to #{fallback_client.name}")
          fallback_client.generate(prompt, timeout: timeout, **options)
        else
          response
        end
      rescue StandardError => e
        Rails.logger.error("LLM Router error: #{e.message}")

        if fallback_client&.available?
          fallback_client.generate(prompt, timeout: timeout, **options)
        else
          Llm::Response.new(
            content: nil,
            provider: client.name,
            error: e.message,
            success: false
          )
        end
      end

      def fallback_response
        Llm::Response.new(
          content: nil,
          provider: :none,
          error: "No LLM providers available",
          success: false
        )
      end
    end
  end
end
