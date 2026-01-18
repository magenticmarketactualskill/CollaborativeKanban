# frozen_string_literal: true

require "logger"

module LlmClient
  class Configuration
    # General settings
    attr_accessor :logger,
                  :default_timeout,
                  :max_retries,
                  :retry_delay

    # LLM settings
    attr_accessor :schema_path

    # API Keys
    attr_accessor :anthropic_api_key,
                  :openai_api_key,
                  :openrouter_api_key,
                  :ollama_host

    # MCP settings
    attr_accessor :mcp_protocol_version,
                  :mcp_client_info

    # Callbacks for database/app integration
    # These allow the gem to work without ActiveRecord while still
    # supporting database persistence when used in a Rails app

    # Called when a tool is invoked (for logging/auditing)
    # Signature: ->(direction, tool_name, arguments, result, error: nil, connection: nil, user: nil)
    # direction: :inbound (external calling us) or :outbound (us calling external)
    attr_accessor :tool_call_logger

    # Called when MCP connection state changes
    # Signature: ->(connection_id, state, error: nil)
    # state: :connecting, :connected, :disconnected, :error
    attr_accessor :connection_state_handler

    # Called to update cached capabilities on a connection
    # Signature: ->(connection_id, tools:, resources:, prompts:)
    attr_accessor :capabilities_updater

    # Called to find a skill by slug
    # Signature: ->(slug, user: nil) -> SkillDefinition or nil
    attr_accessor :skill_finder

    # Called to find enabled connections for a user
    # Signature: ->(user_id) -> Array of connection objects
    attr_accessor :connections_finder

    # Called to get local tools from the MCP server registry
    # Signature: -> Array of ToolDefinition
    attr_accessor :local_tool_provider

    # Called to route an LLM request to a provider
    # Signature: ->(task, prompt, schema: nil, timeout: nil) -> Response
    attr_accessor :llm_router

    def initialize
      @logger = Logger.new($stdout, level: Logger::INFO)
      @default_timeout = 30
      @max_retries = 3
      @retry_delay = 1
      @schema_path = File.join(__dir__, "llm", "schemas")
      @mcp_protocol_version = "2024-11-05"
      @mcp_client_info = { name: "LlmClient", version: LlmClient::VERSION }
      @ollama_host = "http://localhost:11434"
    end

    def validate!
      # Add validation for required settings if needed
    end
  end

  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
      configuration.validate!
    end

    def reset_configuration!
      @configuration = Configuration.new
    end

    def logger
      configuration.logger
    end
  end
end
