# frozen_string_literal: true

module LlmClient
  module Llm
    class Router
      # Task categories and their preferred providers
      ROUTING_TABLE = {
        # Fast, simple tasks -> Ollama (local)
        type_inference: { primary: :ollama, fallback: :claude, timeout: 10, schema: :type_inference },
        classification: { primary: :ollama, fallback: :claude, timeout: 10 },
        extraction: { primary: :ollama, fallback: :claude, timeout: 15 },

        # Complex reasoning tasks -> Claude
        analysis: { primary: :claude, fallback: :ollama, timeout: 45, schema: :content_analysis },
        suggestion: { primary: :claude, fallback: :ollama, timeout: 45, schema: :suggestions },
        schema_generation: { primary: :claude, fallback: nil, timeout: 60 },
        summarization: { primary: :claude, fallback: :ollama, timeout: 30 },
        relationship_detection: { primary: :claude, fallback: :ollama, timeout: 60, schema: :relationship_suggestions },

        # General purpose (defaults to Claude)
        general: { primary: :claude, fallback: :ollama, timeout: 30 }
      }.freeze

      class << self
        def route(task, prompt, **options)
          task = task.to_sym
          routing = ROUTING_TABLE.fetch(task) do
            # Default to general if unknown task
            ROUTING_TABLE[:general]
          end

          client = client_for(routing[:primary])
          fallback_client = routing[:fallback] ? client_for(routing[:fallback]) : nil

          # Use schema from routing table unless explicitly overridden
          schema = options.key?(:schema) ? options[:schema] : routing[:schema]

          execute_with_fallback(
            client: client,
            fallback_client: fallback_client,
            prompt: prompt,
            timeout: options[:timeout] || routing[:timeout],
            schema: schema,
            **options.except(:schema, :timeout)
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

        def execute_with_fallback(client:, fallback_client:, prompt:, timeout:, schema: nil, **options)
          return fallback_response unless client.available?

          client_options = { timeout: timeout, schema: schema, **options }.compact

          response = client.generate(prompt, **client_options)

          if response.success?
            response
          elsif fallback_client&.available?
            LlmClient.logger.warn("LLM Router: Falling back from #{client.name} to #{fallback_client.name}")
            fallback_client.generate(prompt, **client_options)
          else
            response
          end
        rescue StandardError => e
          LlmClient.logger.error("LLM Router error: #{e.message}")

          if fallback_client&.available?
            fallback_client.generate(prompt, **client_options)
          else
            Response.new(
              content: nil,
              provider: client.name,
              error: e.message,
              success: false
            )
          end
        end

        def fallback_response
          Response.new(
            content: nil,
            provider: :none,
            error: "No LLM providers available",
            success: false
          )
        end
      end
    end
  end
end
