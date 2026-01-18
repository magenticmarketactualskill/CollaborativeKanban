# frozen_string_literal: true

require_relative "lib/llm_client/version"

Gem::Specification.new do |spec|
  spec.name = "llm_client"
  spec.version = LlmClient::VERSION
  spec.authors = ["CollaborativeKanban Team"]
  spec.summary = "Multi-provider LLM client with MCP and Skills support"
  spec.description = "A Ruby gem providing LLM integration with multiple providers, MCP (Model Context Protocol) client support, and a skills execution engine."
  spec.homepage = "https://github.com/actual-skill/CollaborativeKanban"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  end
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-retry", "~> 2.0"
  spec.add_dependency "websocket-client-simple", "~> 0.8"
  spec.add_dependency "json_schemer", "~> 2.0"
  spec.add_dependency "rubyzip", "~> 2.3"
end
