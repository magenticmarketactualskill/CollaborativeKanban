module Mcp
  module Server
    module Tools
      class CardAnalyze < Base
        def name
          "card_analyze"
        end

        def description
          "Analyze a kanban card using AI to get insights, complexity score, effort estimation, and suggestions"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_id: { type: "integer", description: "The card ID to analyze" }
            },
            required: %w[card_id]
          }
        end

        def execute(arguments, context:)
          card = find_card(arguments["card_id"], context)

          result = CardIntelligence::ContentAnalyzer.new.analyze(card)

          if result[:success]
            {
              success: true,
              analysis: {
                card_id: card.id,
                card_title: card.title,
                summary: result[:summary],
                complexity: result[:complexity],
                effort_estimate: result[:effort_estimate],
                blockers: result[:blockers],
                subtasks: result[:subtasks],
                topics: result[:topics]
              }
            }
          else
            {
              success: false,
              error: result[:error] || "Analysis failed"
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
