module Mcp
  module Server
    module Tools
      class LlmRoute < Base
        def name
          "llm_route"
        end

        def description
          "Route a prompt through the configured LLM providers with intelligent task-based routing"
        end

        def input_schema
          {
            type: "object",
            properties: {
              prompt: { type: "string", description: "The prompt to send to the LLM" },
              task_type: {
                type: "string",
                enum: %w[type_inference classification extraction analysis suggestion schema_generation general],
                description: "The type of task for routing optimization"
              },
              schema_name: { type: "string", description: "Optional JSON schema name for structured output" }
            },
            required: %w[prompt]
          }
        end

        def execute(arguments, context:)
          prompt = arguments["prompt"]
          task_type = arguments["task_type"] || "general"
          schema_name = arguments["schema_name"]

          result = LlmClient::Llm::Router.route(
            task_type.to_sym,
            prompt,
            schema: schema_name&.to_sym
          )

          if result.success?
            {
              success: true,
              response: result.content,
              provider: result.provider,
              model: result.model,
              tokens: {
                input: result.input_tokens,
                output: result.output_tokens
              }
            }
          else
            {
              success: false,
              error: result.error
            }
          end
        rescue StandardError => e
          {
            success: false,
            error: e.message
          }
        end
      end
    end
  end
end
