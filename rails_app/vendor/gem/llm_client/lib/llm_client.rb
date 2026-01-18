# frozen_string_literal: true

require_relative "llm_client/version"
require_relative "llm_client/errors"
require_relative "llm_client/configuration"

# MCP Client
require_relative "llm_client/mcp/errors"
require_relative "llm_client/mcp/tool_definition"
require_relative "llm_client/mcp/web_socket_client"
require_relative "llm_client/mcp/connection_manager"
require_relative "llm_client/mcp/tool_aggregator"

# Skills
require_relative "llm_client/skills/errors"
require_relative "llm_client/skills/skill_definition"
require_relative "llm_client/skills/executor"
require_relative "llm_client/skills/importer"
require_relative "llm_client/skills/exporter"
require_relative "llm_client/skills/bulk_exporter"

# LLM
require_relative "llm_client/llm/errors"
require_relative "llm_client/llm/response"
require_relative "llm_client/llm/schema_validator"
require_relative "llm_client/llm/base_client"
require_relative "llm_client/llm/claude_client"
require_relative "llm_client/llm/ollama_client"
require_relative "llm_client/llm/router"

# Providers
require_relative "llm_client/providers/provider"
require_relative "llm_client/providers/base"
require_relative "llm_client/providers/anthropic"
require_relative "llm_client/providers/openai"
require_relative "llm_client/providers/ollama"
require_relative "llm_client/providers/openrouter"
require_relative "llm_client/providers/custom"

module LlmClient
  # Convenience method to get a configured tool aggregator
  def self.tool_aggregator(user_id: nil)
    Mcp::ToolAggregator.new(user_id: user_id)
  end

  # Convenience method to execute a skill
  def self.execute_skill(skill_or_slug, params = {}, user: nil)
    skill = case skill_or_slug
            when Skills::SkillDefinition
              skill_or_slug
            when String, Symbol
              finder = configuration.skill_finder
              raise CallbackNotConfiguredError, "skill_finder" unless finder
              finder.call(skill_or_slug.to_s, user: user)
            else
              raise ArgumentError, "Expected SkillDefinition or slug string"
            end

    Skills::Executor.new(skill, params, user: user).call
  end

  # Convenience method to route an LLM request
  def self.llm_request(task, prompt, schema: nil, timeout: nil)
    Llm::Router.route(task, prompt, schema: schema, timeout: timeout)
  end
end
