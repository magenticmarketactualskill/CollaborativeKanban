module Mcp
  module Server
    module Resources
      class BoardData < Base
        def name
          "board-data"
        end

        def uri_template
          "kanban://boards/{board_id}"
        end

        def description
          "Full data export of a kanban board including all columns and cards"
        end

        def read(uri, context:)
          params = extract_params(uri)
          board_id = params[:board_id]

          board = if context[:user]
            context[:user].accessible_boards.find(board_id)
          else
            Board.find(board_id)
          end

          data = {
            id: board.id,
            name: board.name,
            description: board.description,
            level: board.level,
            columns: board.columns.order(:position).map do |column|
              {
                id: column.id,
                name: column.name,
                position: column.position,
                wip_limit: column.wip_limit,
                cards: column.cards.order(:position).map do |card|
                  {
                    id: card.id,
                    title: card.title,
                    description: card.description,
                    card_type: card.card_type,
                    priority: card.priority,
                    due_date: card.due_date&.iso8601,
                    position: card.position,
                    ai_summary: card.ai_summary,
                    created_at: card.created_at.iso8601,
                    updated_at: card.updated_at.iso8601
                  }
                end
              }
            end,
            created_at: board.created_at.iso8601,
            updated_at: board.updated_at.iso8601
          }

          {
            uri: uri,
            mimeType: mime_type,
            text: data.to_json
          }
        end
      end
    end
  end
end
