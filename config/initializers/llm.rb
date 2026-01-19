# frozen_string_literal: true

# LLM Configuration for Hybrid Multi-Provider Integration
#
# This initializer configures the LLM system with support for multiple providers:
# - Ollama (local) for fast, frequent operations like card type inference
# - Anthropic (Claude) for complex reasoning like content analysis
# - OpenAI for general purpose tasks
# - OpenRouter for access to multiple models
# - Custom OpenAI-compatible endpoints
#
# Configurations are stored in the database via LlmConfiguration model.
# Use LlmConfiguration::Setup to manage default configurations.

Rails.application.config.to_prepare do
  # Reset clients on code reload (development)
  Llm::Router.reset_clients! if defined?(Llm::Router)
end

# Feature flags for LLM functionality
Rails.application.config.llm = ActiveSupport::OrderedOptions.new
Rails.application.config.llm.enabled = ENV.fetch("LLM_ENABLED", "true") == "true"
Rails.application.config.llm.auto_infer_type = ENV.fetch("LLM_AUTO_INFER_TYPE", "true") == "true"
Rails.application.config.llm.auto_analyze = ENV.fetch("LLM_AUTO_ANALYZE", "false") == "true"
Rails.application.config.llm.auto_suggest = ENV.fetch("LLM_AUTO_SUGGEST", "false") == "true"

# Legacy configuration (for backwards compatibility with existing Llm::Router)
# These will be overridden by database configurations when available
Rails.application.config.llm.ollama = ActiveSupport::OrderedOptions.new
Rails.application.config.llm.ollama.host = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
Rails.application.config.llm.ollama.model = ENV.fetch("OLLAMA_MODEL", "llama3.2:3b")
Rails.application.config.llm.ollama.timeout = ENV.fetch("OLLAMA_TIMEOUT", "15").to_i

Rails.application.config.llm.claude = ActiveSupport::OrderedOptions.new
Rails.application.config.llm.claude.model = ENV.fetch("CLAUDE_MODEL", "claude-3-5-haiku-20241022")
Rails.application.config.llm.claude.timeout = ENV.fetch("CLAUDE_TIMEOUT", "60").to_i

# Initialize database configurations after Rails is fully loaded
Rails.application.config.after_initialize do
  if ActiveRecord::Base.connection.table_exists?(:llm_configurations)
    LlmConfig::Setup.call
  end
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Database not yet created or migrated - skip setup
  Rails.logger.info "[LLM] Skipping LlmConfig::Setup - database not ready"
end
