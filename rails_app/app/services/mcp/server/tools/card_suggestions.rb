module Mcp
  module Server
    module Tools
      class CardSuggestions < Base
        def name
          "card_suggestions"
        end

        def description
          "Get AI-generated suggestions for improving a kanban card"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_id: { type: "integer", description: "The card ID to get suggestions for" }
            },
            required: %w[card_id]
          }
        end

        def execute(arguments, context:)
          card = find_card(arguments["card_id"], context)

          result = CardIntelligence::SuggestionGenerator.new.generate(card)

          if result[:success]
            {
              success: true,
              suggestions: result[:suggestions].map do |s|
                {
                  type: s[:type],
                  content: s[:content],
                  confidence: s[:confidence]
                }
              end
            }
          else
            {
              success: false,
              error: result[:error] || "Suggestion generation failed"
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
