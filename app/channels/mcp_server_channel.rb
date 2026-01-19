class McpServerChannel < ApplicationCable::Channel
  def subscribed
    @config = McpServerConfiguration.current(current_user)

    unless @config.enabled
      reject
      return
    end

    unless authenticate_mcp_request
      reject
      return
    end

    @handler = Mcp::Server::JsonRpcHandler.new(
      config: @config,
      context: {
        user: current_user,
        connection_id: connection.connection_identifier
      }
    )

    # Initialize registries if needed
    Mcp::Server::ToolRegistry.instance.register_defaults! if Mcp::Server::ToolRegistry.instance.all.empty?
    Mcp::Server::ResourceRegistry.instance.register_defaults! if Mcp::Server::ResourceRegistry.instance.list.empty?

    stream_from mcp_stream_name
    Rails.logger.info("MCP Server: Client subscribed (user: #{current_user&.id || 'anonymous'})")
  end

  def receive(data)
    Rails.logger.debug("MCP Server received: #{data.inspect}")

    response = @handler.handle(data)

    if response
      transmit(response)
      Rails.logger.debug("MCP Server sent: #{response.inspect}")
    end
  rescue StandardError => e
    Rails.logger.error("MCP Server error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    transmit({
      jsonrpc: "2.0",
      id: data&.dig("id"),
      error: { code: -32603, message: "Internal error: #{e.message}" }
    })
  end

  def unsubscribed
    Rails.logger.info("MCP Server: Client unsubscribed (user: #{current_user&.id || 'anonymous'})")
  end

  private

  def mcp_stream_name
    if current_user
      "mcp_server_user_#{current_user.id}"
    else
      "mcp_server_anonymous_#{connection.connection_identifier}"
    end
  end

  def authenticate_mcp_request
    return true if @config.auth_type == "none"

    case @config.auth_type
    when "token"
      token = params[:token]
      @config.valid_token?(token)
    else
      true
    end
  end
end
