module Mcp
  module Server
    module Tools
      class CardCreate < Base
        def name
          "card_create"
        end

        def description
          "Create a new card on a kanban board column"
        end

        def input_schema
          {
            type: "object",
            properties: {
              column_id: { type: "integer", description: "The column ID to add the card to" },
              title: { type: "string", description: "The card title" },
              description: { type: "string", description: "The card description (optional)" },
              card_type: { type: "string", enum: %w[task checklist bug milestone], description: "The type of card" },
              priority: { type: "string", enum: %w[low medium high urgent], description: "Card priority" },
              due_date: { type: "string", format: "date", description: "Due date in YYYY-MM-DD format" }
            },
            required: %w[column_id title]
          }
        end

        def execute(arguments, context:)
          column = Column.find(arguments["column_id"])
          board = column.board
          require_board_access!(board, context)

          card = column.cards.create!(
            title: arguments["title"],
            description: arguments["description"],
            card_type: arguments["card_type"] || "task",
            priority: arguments["priority"],
            due_date: arguments["due_date"],
            position: column.cards.maximum(:position).to_i + 1
          )

          {
            success: true,
            card: {
              id: card.id,
              title: card.title,
              card_type: card.card_type,
              column_id: card.column_id,
              position: card.position
            }
          }
        end
      end
    end
  end
end
