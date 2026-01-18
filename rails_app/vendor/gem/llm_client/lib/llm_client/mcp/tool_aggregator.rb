# frozen_string_literal: true

module LlmClient
  module Mcp
    class ToolAggregator
      attr_reader :user_id

      def initialize(user_id: nil)
        @user_id = user_id
      end

      def available_tools
        local_tools + external_tools
      end

      def local_tools
        provider = LlmClient.configuration.local_tool_provider
        return [] unless provider

        tools = provider.call
        tools.map do |tool|
          if tool.is_a?(ToolDefinition)
            tool
          else
            ToolDefinition.new(
              name: tool[:name] || tool["name"],
              description: tool[:description] || tool["description"],
              input_schema: tool[:input_schema] || tool[:inputSchema] || tool["inputSchema"],
              source: :local
            )
          end
        end
      end

      def external_tools
        finder = LlmClient.configuration.connections_finder
        return [] unless finder

        connections = finder.call(@user_id)
        connections.flat_map do |conn|
          cached = conn.respond_to?(:cached_tools) ? conn.cached_tools : []
          cached.map do |tool|
            ToolDefinition.new(
              name: tool["name"] || tool[:name],
              description: tool["description"] || tool[:description],
              input_schema: tool["inputSchema"] || tool[:inputSchema] || tool[:input_schema],
              source: :external,
              connection: conn
            )
          end
        end
      end

      def find_tool(full_name)
        available_tools.find { |t| t.full_name == full_name }
      end

      def call_tool(full_name, arguments = {})
        if full_name.include?("/")
          call_external_tool(full_name, arguments)
        else
          call_local_tool(full_name, arguments)
        end
      end

      private

      def call_external_tool(full_name, arguments)
        conn_name, tool_name = full_name.split("/", 2)

        finder = LlmClient.configuration.connections_finder
        raise CallbackNotConfiguredError, "connections_finder" unless finder

        connections = finder.call(@user_id)
        connection = connections.find { |c| c.name == conn_name }
        raise ToolNotFoundError, "Connection '#{conn_name}' not found" unless connection

        client = ConnectionManager.instance.connect(connection)
        client.call_tool(tool_name, arguments)
      end

      def call_local_tool(tool_name, arguments)
        tool = find_local_tool(tool_name)
        raise ToolNotFoundError, "Tool '#{tool_name}' not found" unless tool

        log_tool_call(:inbound, tool_name, arguments) do
          if tool.respond_to?(:execute)
            tool.execute(arguments, context: { user_id: @user_id })
          elsif tool.respond_to?(:call)
            tool.call(arguments)
          else
            raise Error, "Tool #{tool_name} does not respond to execute or call"
          end
        end
      end

      def find_local_tool(tool_name)
        provider = LlmClient.configuration.local_tool_provider
        return nil unless provider

        tools = provider.call
        tools.find { |t| (t.respond_to?(:name) ? t.name : t[:name]) == tool_name }
      end

      def log_tool_call(direction, tool_name, arguments)
        logger = LlmClient.configuration.tool_call_logger
        result = nil
        error = nil

        begin
          result = yield
        rescue StandardError => e
          error = e.message
          raise
        ensure
          logger&.call(direction, tool_name, arguments, result, error: error, user_id: @user_id)
        end

        result
      end
    end
  end
end
