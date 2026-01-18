# frozen_string_literal: true

require "websocket-client-simple"
require "json"
require "timeout"

module LlmClient
  module Mcp
    class WebSocketClient
      DEFAULT_TIMEOUT = 30

      attr_reader :connection

      # connection: Object that responds to :id, :url, :auth_type, :auth_token
      def initialize(connection)
        @connection = connection
        @ws = nil
        @request_id = 0
        @pending_requests = {}
        @mutex = Mutex.new
        @connected = false
      end

      def connect
        notify_state_change(:connecting)

        begin
          @ws = WebSocket::Client::Simple.connect(connection_url, headers: auth_headers)
          setup_handlers
          wait_for_connection
          initialize_mcp_connection
          @connected = true
          notify_state_change(:connected)
        rescue StandardError => e
          notify_state_change(:error, error: e.message)
          raise ConnectionError, "Failed to connect: #{e.message}"
        end
      end

      def disconnect
        @ws&.close
        @connected = false
        notify_state_change(:disconnected)
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
        log_tool_call(:outbound, tool_name, arguments) do
          call_method("tools/call", { name: tool_name, arguments: arguments })
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

        notify_capabilities_update(tools: tools, resources: resources, prompts: prompts)

        { tools: tools, resources: resources, prompts: prompts }
      end

      private

      def next_request_id
        @mutex.synchronize { @request_id += 1 }
      end

      def connection_url
        @connection.respond_to?(:url) ? @connection.url : @connection.to_s
      end

      def connection_id
        @connection.respond_to?(:id) ? @connection.id : @connection.object_id
      end

      def auth_headers
        auth_type = @connection.respond_to?(:auth_type) ? @connection.auth_type : nil
        auth_token = @connection.respond_to?(:auth_token) ? @connection.auth_token : nil

        case auth_type
        when "token"
          { "Authorization" => "Bearer #{auth_token}" }
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
          LlmClient.logger.error("MCP WebSocket error: #{e.message}")
        end

        @ws.on :close do |_e|
          client.instance_variable_set(:@connected, false)
        end
      end

      def wait_for_connection(timeout: 10)
        start = Time.now
        until @ws.open?
          raise ConnectionError, "Connection timeout" if Time.now - start > timeout
          sleep 0.1
        end
      end

      def initialize_mcp_connection
        config = LlmClient.configuration
        call_method("initialize", {
          protocolVersion: config.mcp_protocol_version,
          capabilities: {},
          clientInfo: config.mcp_client_info
        })
      end

      def handle_message(data)
        message = JSON.parse(data, symbolize_names: true)

        if message[:id] && @pending_requests[message[:id]]
          queue = @mutex.synchronize { @pending_requests.delete(message[:id]) }
          queue&.push(message[:error] ? { error: message[:error] } : message[:result])
        end
      rescue JSON::ParserError => e
        LlmClient.logger.error("MCP: Failed to parse message: #{e.message}")
      end

      def notify_state_change(state, error: nil)
        handler = LlmClient.configuration.connection_state_handler
        handler&.call(connection_id, state, error: error)
      end

      def notify_capabilities_update(tools:, resources:, prompts:)
        updater = LlmClient.configuration.capabilities_updater
        updater&.call(connection_id, tools: tools, resources: resources, prompts: prompts)
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
          logger&.call(direction, tool_name, arguments, result, error: error, connection: @connection)
        end

        result
      end
    end
  end
end
