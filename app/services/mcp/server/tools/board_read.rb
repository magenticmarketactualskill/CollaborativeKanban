module Mcp
  module Server
    module Tools
      class BoardRead < Base
        def name
          "board_read"
        end

        def description
          "Read details of a kanban board including its columns and cards"
        end

        def input_schema
          {
            type: "object",
            properties: {
              board_id: { type: "integer", description: "The board ID to read" },
              include_cards: { type: "boolean", description: "Include cards in each column (default: true)" }
            },
            required: %w[board_id]
          }
        end

        def execute(arguments, context:)
          board = find_board(arguments["board_id"], context)
          include_cards = arguments.fetch("include_cards", true)

          columns_data = board.columns.order(:position).map do |column|
            column_info = {
              id: column.id,
              name: column.name,
              position: column.position,
              wip_limit: column.wip_limit,
              cards_count: column.cards.count
            }

            if include_cards
              column_info[:cards] = column.cards.order(:position).map do |card|
                {
                  id: card.id,
                  title: card.title,
                  card_type: card.card_type,
                  priority: card.priority,
                  due_date: card.due_date&.iso8601,
                  position: card.position
                }
              end
            end

            column_info
          end

          {
            success: true,
            board: {
              id: board.id,
              name: board.name,
              description: board.description,
              level: board.level,
              columns: columns_data,
              created_at: board.created_at.iso8601,
              updated_at: board.updated_at.iso8601
            }
          }
        end
      end
    end
  end
end
