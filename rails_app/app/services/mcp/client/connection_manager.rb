module Mcp
  module Client
    class ConnectionManager
      include Singleton

      def initialize
        @connections = {}
        @mutex = Mutex.new
      end

      def connect(mcp_client_connection)
        @mutex.synchronize do
          existing = @connections[mcp_client_connection.id]
          return existing if existing&.connected?

          client = WebSocketClient.new(mcp_client_connection)
          client.connect
          @connections[mcp_client_connection.id] = client
          client
        end
      end

      def disconnect(mcp_client_connection)
        @mutex.synchronize do
          client = @connections.delete(mcp_client_connection.id)
          client&.disconnect
        end
      end

      def client_for(mcp_client_connection)
        @mutex.synchronize { @connections[mcp_client_connection.id] }
      end

      def connected?(mcp_client_connection)
        client = client_for(mcp_client_connection)
        client&.connected? || false
      end

      def refresh_capabilities(mcp_client_connection)
        client = client_for(mcp_client_connection)
        raise NotConnectedError, "Not connected" unless client&.connected?
        client.refresh_capabilities
      end

      def disconnect_all
        @mutex.synchronize do
          @connections.each_value(&:disconnect)
          @connections.clear
        end
      end

      def active_connections
        @mutex.synchronize do
          @connections.select { |_id, client| client.connected? }
        end
      end
    end
  end
end
