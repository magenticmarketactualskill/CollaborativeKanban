module Mcp
  module Server
    module Tools
      class BoardList < Base
        def name
          "board_list"
        end

        def description
          "List all kanban boards accessible to the current user"
        end

        def input_schema
          {
            type: "object",
            properties: {
              level: { type: "string", enum: %w[personal team group enterprise], description: "Filter by board level" }
            },
            required: []
          }
        end

        def execute(arguments, context:)
          boards = if context[:user]
            context[:user].accessible_boards
          else
            Board.all
          end

          boards = boards.where(level: arguments["level"]) if arguments["level"].present?

          {
            success: true,
            boards: boards.map do |board|
              {
                id: board.id,
                name: board.name,
                description: board.description,
                level: board.level,
                columns_count: board.columns.count,
                cards_count: board.columns.joins(:cards).count,
                created_at: board.created_at.iso8601
              }
            end
          }
        end
      end
    end
  end
end
