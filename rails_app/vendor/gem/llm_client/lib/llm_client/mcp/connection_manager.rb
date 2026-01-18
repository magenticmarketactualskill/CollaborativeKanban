# frozen_string_literal: true

require "singleton"

module LlmClient
  module Mcp
    class ConnectionManager
      include Singleton

      def initialize
        @connections = {}
        @mutex = Mutex.new
      end

      # Connect to an MCP server
      # connection: Object that responds to :id, :url, :auth_type, :auth_token
      def connect(connection)
        @mutex.synchronize do
          conn_id = connection_id(connection)
          existing = @connections[conn_id]
          return existing if existing&.connected?

          client = WebSocketClient.new(connection)
          client.connect
          @connections[conn_id] = client
          client
        end
      end

      def disconnect(connection)
        @mutex.synchronize do
          conn_id = connection_id(connection)
          client = @connections.delete(conn_id)
          client&.disconnect
        end
      end

      def client_for(connection)
        @mutex.synchronize { @connections[connection_id(connection)] }
      end

      def connected?(connection)
        client = client_for(connection)
        client&.connected? || false
      end

      def refresh_capabilities(connection)
        client = client_for(connection)
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

      private

      def connection_id(connection)
        connection.respond_to?(:id) ? connection.id : connection.object_id
      end
    end
  end
end
