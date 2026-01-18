# frozen_string_literal: true

require_relative "lib/entity_knowledge/version"

Gem::Specification.new do |spec|
  spec.name = "entity_knowledge"
  spec.version = EntityKnowledge::VERSION
  spec.authors = ["CollaborativeKanban Team"]
  spec.summary = "Knowledge graph engine for entity and fact extraction"
  spec.description = "A Rails Engine providing entity extraction, fact management, and knowledge graph functionality with pattern-based and fuzzy matching extraction."
  spec.homepage = "https://github.com/actual-skill/CollaborativeKanban"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
end
