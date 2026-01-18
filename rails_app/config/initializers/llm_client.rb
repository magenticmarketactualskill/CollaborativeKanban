# frozen_string_literal: true

# Configure the LlmClient gem for Rails integration
LlmClient.configure do |config|
  # Basic settings
  config.logger = Rails.logger
  config.schema_path = Rails.root.join("vendor/gem/llm_client/lib/llm_client/llm/schemas").to_s

  # API Keys from credentials or environment
  config.anthropic_api_key = Rails.application.credentials.dig(:anthropic, :api_key) || ENV["ANTHROPIC_API_KEY"]
  config.openai_api_key = Rails.application.credentials.dig(:openai, :api_key) || ENV["OPENAI_API_KEY"]
  config.openrouter_api_key = Rails.application.credentials.dig(:openrouter, :api_key) || ENV["OPENROUTER_API_KEY"]
  config.ollama_host = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")

  # Tool call logging callback
  config.tool_call_logger = lambda do |direction, tool_name, arguments, result, error: nil, connection: nil, user_id: nil|
    user = user_id.is_a?(Integer) ? User.find_by(id: user_id) : user_id

    call = if direction == :inbound
             McpToolCall.log_inbound(tool_name: tool_name, arguments: arguments, user: user)
           else
             McpToolCall.log_outbound(tool_name: tool_name, arguments: arguments, connection: connection, user: user)
           end

    if error
      call.fail!(error)
    else
      call.complete!(result)
    end
  end

  # Connection state change callback
  config.connection_state_handler = lambda do |connection_id, state, error: nil|
    conn = McpClientConnection.find_by(id: connection_id)
    return unless conn

    case state
    when :connecting
      conn.update!(status: "connecting")
    when :connected
      conn.mark_connected!
    when :disconnected
      conn.mark_disconnected!
    when :error
      conn.mark_error!(error)
    end
  end

  # Capabilities update callback
  config.capabilities_updater = lambda do |connection_id, tools:, resources:, prompts:|
    conn = McpClientConnection.find_by(id: connection_id)
    conn&.update_capabilities(tools: tools, resources: resources, prompts: prompts)
  end

  # Skill finder callback
  config.skill_finder = lambda do |slug, user: nil|
    skill = Skill.enabled.for_user(user).find_by(slug: slug)
    return nil unless skill

    LlmClient::Skills::SkillDefinition.from_record(skill)
  end

  # Connections finder callback
  config.connections_finder = lambda do |user_id|
    user = user_id.is_a?(Integer) ? User.find_by(id: user_id) : user_id
    McpClientConnection.enabled.for_user(user).to_a
  end

  # Local tool provider callback
  config.local_tool_provider = lambda do
    Mcp::Server::ToolRegistry.instance.all.map do |tool|
      LlmClient::Mcp::ToolDefinition.new(
        name: tool.name,
        description: tool.description,
        input_schema: tool.input_schema,
        source: :local
      )
    end
  end

  # LLM router callback (uses the gem's built-in router)
  config.llm_router = lambda do |task, prompt, schema: nil, timeout: nil|
    LlmClient::Llm::Router.route(task, prompt, schema: schema, timeout: timeout)
  end
end
