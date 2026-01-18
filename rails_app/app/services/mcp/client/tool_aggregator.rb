module Mcp
  module Client
    class ToolAggregator
      def initialize(user: nil)
        @user = user
      end

      def available_tools
        local_tools + external_tools
      end

      def local_tools
        Mcp::Server::ToolRegistry.instance.all.map do |tool|
          ToolDefinition.new(
            name: tool.name,
            description: tool.description,
            input_schema: tool.input_schema,
            source: :local
          )
        end
      end

      def external_tools
        connections = McpClientConnection.enabled.for_user(@user)

        connections.flat_map do |conn|
          conn.cached_tools.map do |tool|
            ToolDefinition.new(
              name: tool["name"],
              description: tool["description"],
              input_schema: tool["inputSchema"],
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
        connection = McpClientConnection.enabled.for_user(@user).find_by!(name: conn_name)

        client = ConnectionManager.instance.connect(connection)
        client.call_tool(tool_name, arguments)
      end

      def call_local_tool(tool_name, arguments)
        tool = Mcp::Server::ToolRegistry.instance.tool(tool_name)
        raise Mcp::Server::ToolNotFoundError, tool_name unless tool

        call_record = McpToolCall.log_inbound(
          tool_name: tool_name,
          arguments: arguments,
          user: @user
        )

        begin
          result = tool.execute(arguments, context: { user: @user })
          call_record.complete!(result)
          result
        rescue StandardError => e
          call_record.fail!(e.message)
          raise
        end
      end
    end
  end
end
