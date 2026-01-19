module Mcp
  module Server
    module Tools
      class Base
        def name
          raise NotImplementedError, "#{self.class} must implement #name"
        end

        def description
          raise NotImplementedError, "#{self.class} must implement #description"
        end

        def input_schema
          raise NotImplementedError, "#{self.class} must implement #input_schema"
        end

        def execute(arguments, context:)
          raise NotImplementedError, "#{self.class} must implement #execute"
        end

        def to_definition
          {
            name: name,
            description: description,
            inputSchema: input_schema
          }
        end

        protected

        def require_user!(context)
          raise Mcp::Server::UnauthorizedError, "Authentication required" unless context[:user]
        end

        def require_board_access!(board, context)
          require_user!(context)
          unless context[:user].can_access_board?(board)
            raise Mcp::Server::UnauthorizedError, "No access to board #{board.id}"
          end
        end

        def find_board(id, context)
          if context[:user]
            context[:user].accessible_boards.find(id)
          else
            Board.find(id)
          end
        end

        def find_card(id, context)
          card = Card.find(id)
          require_board_access!(card.column.board, context) if context[:user]
          card
        end
      end
    end
  end
end
