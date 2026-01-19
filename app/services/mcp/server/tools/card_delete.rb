module Mcp
  module Server
    module Tools
      class CardDelete < Base
        def name
          "card_delete"
        end

        def description
          "Delete a kanban card from the board"
        end

        def input_schema
          {
            type: "object",
            properties: {
              card_id: { type: "integer", description: "The card ID to delete" }
            },
            required: %w[card_id]
          }
        end

        def execute(arguments, context:)
          card = find_card(arguments["card_id"], context)
          card_id = card.id
          card_title = card.title

          card.destroy!

          {
            success: true,
            deleted: {
              id: card_id,
              title: card_title
            }
          }
        end
      end
    end
  end
end
