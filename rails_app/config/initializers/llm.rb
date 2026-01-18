# frozen_string_literal: true

# LLM Configuration for Hybrid Ollama + Claude Integration
#
# This initializer configures the LLM routing system that uses:
# - Ollama (local) for fast, frequent operations like card type inference
# - Claude API for complex reasoning like content analysis and suggestions

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

# Ollama configuration (local LLM)
Rails.application.config.llm.ollama = ActiveSupport::OrderedOptions.new
Rails.application.config.llm.ollama.host = ENV.fetch("OLLAMA_HOST", "http://localhost:11434")
Rails.application.config.llm.ollama.model = ENV.fetch("OLLAMA_MODEL", "llama3.2:3b")
Rails.application.config.llm.ollama.timeout = ENV.fetch("OLLAMA_TIMEOUT", "15").to_i

# Claude configuration (Anthropic API)
Rails.application.config.llm.claude = ActiveSupport::OrderedOptions.new
Rails.application.config.llm.claude.model = ENV.fetch("CLAUDE_MODEL", "claude-3-5-haiku-20241022")
Rails.application.config.llm.claude.timeout = ENV.fetch("CLAUDE_TIMEOUT", "60").to_i
