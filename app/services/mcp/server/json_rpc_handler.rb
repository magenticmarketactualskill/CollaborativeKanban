module Mcp
  module Server
    class JsonRpcHandler
      JSONRPC_VERSION = "2.0"
      MCP_PROTOCOL_VERSION = "2024-11-05"

      def initialize(config:, context:)
        @config = config
        @context = context
        @tool_registry = ToolRegistry.instance
        @resource_registry = ResourceRegistry.instance
      end

      def handle(message)
        request = parse_request(message)

        case request[:method]
        when "initialize"
          handle_initialize(request)
        when "initialized"
          handle_initialized(request)
        when "tools/list"
          handle_tools_list(request)
        when "tools/call"
          handle_tools_call(request)
        when "resources/list"
          handle_resources_list(request)
        when "resources/read"
          handle_resources_read(request)
        when "prompts/list"
          handle_prompts_list(request)
        when "prompts/get"
          handle_prompts_get(request)
        when "ping"
          handle_ping(request)
        else
          error_response(request[:id], -32601, "Method not found: #{request[:method]}")
        end
      rescue JSON::ParserError => e
        error_response(nil, -32700, "Parse error: #{e.message}")
      rescue ValidationError => e
        error_response(request&.dig(:id), -32602, e.message)
      rescue ToolNotFoundError => e
        error_response(request&.dig(:id), -32602, "Tool not found: #{e.message}")
      rescue UnauthorizedError => e
        error_response(request&.dig(:id), -32603, "Unauthorized: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("MCP Server error: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        error_response(request&.dig(:id), -32603, "Internal error: #{e.message}")
      end

      private

      def parse_request(message)
        data = message.is_a?(String) ? JSON.parse(message, symbolize_names: true) : message
        data
      end

      def handle_initialize(request)
        success_response(request[:id], {
          protocolVersion: MCP_PROTOCOL_VERSION,
          capabilities: {
            tools: { listChanged: true },
            resources: { subscribe: false, listChanged: true },
            prompts: { listChanged: true }
          },
          serverInfo: {
            name: "CollaborativeKanban MCP Server",
            version: "1.0.0"
          }
        })
      end

      def handle_initialized(request)
        # No response needed for initialized notification
        nil
      end

      def handle_tools_list(request)
        tools = @tool_registry.list(@config)
        success_response(request[:id], { tools: tools })
      end

      def handle_tools_call(request)
        params = request[:params] || {}
        tool_name = params[:name]
        arguments = params[:arguments] || {}

        tool = @tool_registry.tool(tool_name)
        raise ToolNotFoundError, tool_name unless tool

        call_record = McpToolCall.log_inbound(
          tool_name: tool_name,
          arguments: arguments,
          user: @context[:user]
        )

        begin
          result = tool.execute(arguments, context: @context)
          call_record.complete!(result)

          content = format_tool_result(result)
          success_response(request[:id], { content: content })
        rescue StandardError => e
          call_record.fail!(e.message)
          raise
        end
      end

      def handle_resources_list(request)
        resources = @resource_registry.list(@config)
        success_response(request[:id], { resources: resources })
      end

      def handle_resources_read(request)
        params = request[:params] || {}
        uri = params[:uri]

        content = @resource_registry.read(uri, context: @context)
        success_response(request[:id], { contents: [ content ] })
      end

      def handle_prompts_list(request)
        prompts = Skill.enabled.for_user(@context[:user]).map do |skill|
          {
            name: skill.slug,
            description: skill.description,
            arguments: skill.parameters.map do |p|
              {
                name: p["name"],
                description: p["description"],
                required: p["required"] || false
              }
            end
          }
        end
        success_response(request[:id], { prompts: prompts })
      end

      def handle_prompts_get(request)
        params = request[:params] || {}
        skill = Skill.for_user(@context[:user]).find_by!(slug: params[:name])
        arguments = params[:arguments] || {}

        prompt_text = render_prompt(skill, arguments)

        success_response(request[:id], {
          description: skill.description,
          messages: [
            { role: "user", content: { type: "text", text: prompt_text } }
          ]
        })
      rescue ActiveRecord::RecordNotFound
        error_response(request[:id], -32602, "Prompt not found: #{params[:name]}")
      end

      def handle_ping(request)
        success_response(request[:id], {})
      end

      def format_tool_result(result)
        case result
        when Hash
          [ { type: "text", text: result.to_json } ]
        when String
          [ { type: "text", text: result } ]
        when Array
          result.map { |r| { type: "text", text: r.to_s } }
        else
          [ { type: "text", text: result.to_s } ]
        end
      end

      def render_prompt(skill, arguments)
        template = skill.prompt_template
        arguments.each do |key, value|
          template = template.gsub("{{#{key}}}", value.to_s)
        end
        template
      end

      def success_response(id, result)
        { jsonrpc: JSONRPC_VERSION, id: id, result: result }
      end

      def error_response(id, code, message)
        { jsonrpc: JSONRPC_VERSION, id: id, error: { code: code, message: message } }
      end
    end

    class ValidationError < StandardError; end
    class ToolNotFoundError < StandardError; end
    class UnauthorizedError < StandardError; end
  end
end
