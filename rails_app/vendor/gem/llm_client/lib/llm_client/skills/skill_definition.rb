# frozen_string_literal: true

module LlmClient
  module Skills
    # Pure Ruby object representing a skill definition
    # This is the gem's equivalent of the ActiveRecord Skill model
    class SkillDefinition
      CATEGORIES = %w[analysis generation workflow transformation extraction].freeze

      attr_accessor :name, :slug, :version, :description, :category,
                    :parameters, :prompt_template, :workflow_steps,
                    :dependencies, :metadata, :enabled, :system_skill,
                    :source, :source_file

      def initialize(
        name:,
        slug: nil,
        version: "1.0.0",
        description: nil,
        category: nil,
        parameters: [],
        prompt_template: "{{input}}",
        workflow_steps: [],
        dependencies: [],
        metadata: {},
        enabled: true,
        system_skill: false,
        source: nil,
        source_file: nil
      )
        @name = name
        @slug = slug || name&.downcase&.gsub(/[^a-z0-9]+/, "-")&.gsub(/^-|-$/, "")
        @version = version
        @description = description
        @category = category
        @parameters = parameters || []
        @prompt_template = prompt_template
        @workflow_steps = workflow_steps || []
        @dependencies = dependencies || []
        @metadata = metadata || {}
        @enabled = enabled
        @system_skill = system_skill
        @source = source
        @source_file = source_file
      end

      def parameter_names
        parameters.map { |p| p["name"] || p[:name] }
      end

      def required_parameters
        parameters.select { |p| p["required"] || p[:required] }
      end

      def has_workflow?
        workflow_steps.any?
      end

      def to_h
        {
          name: name,
          slug: slug,
          version: version,
          description: description,
          category: category,
          parameters: parameters,
          prompt_template: prompt_template,
          workflow_steps: workflow_steps,
          dependencies: dependencies,
          metadata: metadata,
          enabled: enabled,
          system_skill: system_skill,
          source: source,
          source_file: source_file
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      # Create from a hash (e.g., from JSON or ActiveRecord attributes)
      def self.from_hash(hash)
        hash = hash.transform_keys(&:to_sym)
        new(**hash.slice(
          :name, :slug, :version, :description, :category,
          :parameters, :prompt_template, :workflow_steps,
          :dependencies, :metadata, :enabled, :system_skill,
          :source, :source_file
        ))
      end

      # Create from an ActiveRecord-like object
      def self.from_record(record)
        new(
          name: record.name,
          slug: record.slug,
          version: record.version,
          description: record.description,
          category: record.category,
          parameters: record.parameters,
          prompt_template: record.prompt_template,
          workflow_steps: record.workflow_steps,
          dependencies: record.dependencies,
          metadata: record.metadata,
          enabled: record.enabled,
          system_skill: record.system_skill,
          source: record.source,
          source_file: record.source_file
        )
      end
    end
  end
end
