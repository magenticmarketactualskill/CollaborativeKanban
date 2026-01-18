require "websocket-client-simple"

module Mcp
  module Client
    class WebSocketClient
      MCP_PROTOCOL_VERSION = "2024-11-05"
      DEFAULT_TIMEOUT = 30

      attr_reader :connection

      def initialize(connection)
        @connection = connection
        @ws = nil
        @request_id = 0
        @pending_requests = {}
        @mutex = Mutex.new
        @connected = false
      end

      def connect
        @connection.update!(status: "connecting")

        begin
          @ws = WebSocket::Client::Simple.connect(@connection.url, headers: auth_headers)
          setup_handlers
          wait_for_connection
          initialize_mcp_connection
          @connected = true
          @connection.mark_connected!
        rescue StandardError => e
          @connection.mark_error!(e.message)
          raise ConnectionError, "Failed to connect: #{e.message}"
        end
      end

      def disconnect
        @ws&.close
        @connected = false
        @connection.mark_disconnected!
      end

      def connected?
        @connected && @ws&.open?
      end

      def call_method(method, params = {}, timeout: DEFAULT_TIMEOUT)
        raise NotConnectedError, "Not connected to MCP server" unless connected?

        request_id = next_request_id
        request = {
          jsonrpc: "2.0",
          id: request_id,
          method: method,
          params: params
        }

        queue = Queue.new
        @mutex.synchronize { @pending_requests[request_id] = queue }

        @ws.send(request.to_json)

        begin
          result = Timeout.timeout(timeout) { queue.pop }
          if result.is_a?(Hash) && result[:error]
            raise RpcError.new(result[:error][:code], result[:error][:message])
          end
          result
        rescue Timeout::Error
          @mutex.synchronize { @pending_requests.delete(request_id) }
          raise TimeoutError, "Request timed out after #{timeout} seconds"
        end
      end

      def call_tool(tool_name, arguments = {})
        call_record = McpToolCall.log_outbound(
          tool_name: tool_name,
          arguments: arguments,
          connection: @connection
        )

        begin
          result = call_method("tools/call", { name: tool_name, arguments: arguments })
          call_record.complete!(result)
          result
        rescue StandardError => e
          call_record.fail!(e.message)
          raise
        end
      end

      def list_tools
        result = call_method("tools/list")
        result[:tools] || []
      end

      def list_resources
        result = call_method("resources/list")
        result[:resources] || []
      end

      def list_prompts
        result = call_method("prompts/list")
        result[:prompts] || []
      end

      def refresh_capabilities
        tools = list_tools
        resources = list_resources
        prompts = list_prompts

        @connection.update_capabilities(
          tools: tools,
          resources: resources,
          prompts: prompts
        )

        { tools: tools, resources: resources, prompts: prompts }
      end

      private

      def next_request_id
        @mutex.synchronize { @request_id += 1 }
      end

      def auth_headers
        case @connection.auth_type
        when "token"
          { "Authorization" => "Bearer #{@connection.auth_token}" }
        else
          {}
        end
      end

      def setup_handlers
        client = self

        @ws.on :message do |msg|
          client.send(:handle_message, msg.data)
        end

        @ws.on :error do |e|
          Rails.logger.error("MCP WebSocket error: #{e.message}")
        end

        @ws.on :close do |_e|
          client.instance_variable_set(:@connected, false)
        end
      end

      def wait_for_connection(timeout: 10)
        start = Time.current
        until @ws.open?
          raise ConnectionError, "Connection timeout" if Time.current - start > timeout
          sleep 0.1
        end
      end

      def initialize_mcp_connection
        call_method("initialize", {
          protocolVersion: MCP_PROTOCOL_VERSION,
          capabilities: {},
          clientInfo: { name: "CollaborativeKanban", version: "1.0.0" }
        })
      end

      def handle_message(data)
        message = JSON.parse(data, symbolize_names: true)

        if message[:id] && @pending_requests[message[:id]]
          queue = @mutex.synchronize { @pending_requests.delete(message[:id]) }
          queue&.push(message[:error] ? { error: message[:error] } : message[:result])
        end
      rescue JSON::ParserError => e
        Rails.logger.error("MCP: Failed to parse message: #{e.message}")
      end
    end

    class ConnectionError < StandardError; end
    class NotConnectedError < StandardError; end
    class TimeoutError < StandardError; end

    class RpcError < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end
  end
end
