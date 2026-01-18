module Mcp
  module Server
    module Tools
      class CardRead < Base
        def name
          "card_read"
        end

        def description
          "Read details of a kanban card including its content, type, and metadata"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_id: { type: "integer", description: "The card ID to read" }
            },
            required: %w[card_id]
          }
        end

        def execute(arguments, context:)
          card = find_card(arguments["card_id"], context)

          {
            success: true,
            card: {
              id: card.id,
              title: card.title,
              description: card.description,
              card_type: card.card_type,
              priority: card.priority,
              due_date: card.due_date&.iso8601,
              position: card.position,
              ai_summary: card.ai_summary,
              inferred_type: card.inferred_type,
              type_confidence: card.type_confidence,
              column: {
                id: card.column.id,
                name: card.column.name
              },
              board: {
                id: card.column.board.id,
                name: card.column.board.name
              },
              created_at: card.created_at.iso8601,
              updated_at: card.updated_at.iso8601
            }
          }
        end
      end
    end
  end
end
