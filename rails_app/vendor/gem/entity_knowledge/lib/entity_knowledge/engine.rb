# frozen_string_literal: true

module EntityKnowledge
  class Engine < ::Rails::Engine
    isolate_namespace EntityKnowledge

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer "entity_knowledge.inflections" do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym "EntityKnowledge"
      end
    end
  end
end
