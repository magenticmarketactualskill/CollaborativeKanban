module Mcp
  module Server
    module Tools
      class CardUpdate < Base
        def name
          "card_update"
        end

        def description
          "Update an existing kanban card's title, description, type, or other attributes"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_id: { type: "integer", description: "The card ID to update" },
              title: { type: "string", description: "New title for the card" },
              description: { type: "string", description: "New description for the card" },
              card_type: { type: "string", enum: %w[task checklist bug milestone], description: "New type for the card" },
              priority: { type: "string", enum: %w[low medium high urgent], description: "New priority" },
              due_date: { type: "string", format: "date", description: "New due date in YYYY-MM-DD format" },
              column_id: { type: "integer", description: "Move card to a different column" }
            },
            required: %w[card_id]
          }
        end

        def execute(arguments, context:)
          card = find_card(arguments["card_id"], context)

          update_params = {}
          update_params[:title] = arguments["title"] if arguments.key?("title")
          update_params[:description] = arguments["description"] if arguments.key?("description")
          update_params[:card_type] = arguments["card_type"] if arguments.key?("card_type")
          update_params[:priority] = arguments["priority"] if arguments.key?("priority")
          update_params[:due_date] = arguments["due_date"] if arguments.key?("due_date")

          if arguments.key?("column_id")
            new_column = Column.find(arguments["column_id"])
            require_board_access!(new_column.board, context)
            update_params[:column_id] = new_column.id
            update_params[:position] = new_column.cards.maximum(:position).to_i + 1
          end

          card.update!(update_params)

          {
            success: true,
            card: {
              id: card.id,
              title: card.title,
              card_type: card.card_type,
              column_id: card.column_id,
              updated_at: card.updated_at.iso8601
            }
          }
        end
      end
    end
  end
end
