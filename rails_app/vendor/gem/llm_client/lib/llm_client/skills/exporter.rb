# frozen_string_literal: true

require "yaml"

module LlmClient
  module Skills
    class Exporter
      attr_reader :skill

      # skill: SkillDefinition or any object responding to skill methods
      def initialize(skill)
        @skill = skill
      end

      def to_markdown
        frontmatter = build_frontmatter
        body = build_body

        "---\n#{frontmatter.to_yaml.sub(/\A---\n/, "")}---\n\n#{body}"
      end

      def to_file(path)
        File.write(path, to_markdown)
        path
      end

      def filename
        "#{skill.slug}.md"
      end

      private

      def build_frontmatter
        fm = {
          "name" => skill.name,
          "slug" => skill.slug,
          "version" => skill.version
        }

        fm["description"] = skill.description if present?(skill.description)
        fm["category"] = skill.category if present?(skill.category)
        fm["parameters"] = skill.parameters if present?(skill.parameters)
        fm["workflow"] = skill.workflow_steps if present?(skill.workflow_steps)
        fm["dependencies"] = skill.dependencies if present?(skill.dependencies)

        if present?(skill.metadata)
          skill.metadata.each do |key, value|
            fm[key.to_s] = value
          end
        end

        fm
      end

      def build_body
        parts = []

        parts << "# #{skill.name}"

        if present?(skill.description)
          parts << ""
          parts << skill.description
        end

        parts << ""
        parts << "## Prompt"
        parts << ""
        parts << "```prompt"
        parts << skill.prompt_template
        parts << "```"

        if present?(skill.parameters)
          parts << ""
          parts << "## Parameters"
          parts << ""
          skill.parameters.each do |p|
            p_name = p["name"] || p[:name]
            p_type = p["type"] || p[:type] || "string"
            p_required = p["required"] || p[:required]
            p_default = p["default"] || p[:default]
            p_desc = p["description"] || p[:description]

            required = p_required ? " (required)" : ""
            default = p_default ? " [default: #{p_default}]" : ""
            parts << "- **#{p_name}** (`#{p_type}`#{required}#{default}): #{p_desc}"
          end
        end

        if present?(skill.workflow_steps)
          parts << ""
          parts << "## Workflow"
          parts << ""
          skill.workflow_steps.each_with_index do |step, i|
            parts << "#{i + 1}. **#{step['type'] || step[:type]}**: #{step_description(step)}"
          end
        end

        parts.join("\n")
      end

      def step_description(step)
        step_type = step["type"] || step[:type]
        output_key = step["output_key"] || step[:output_key]

        case step_type
        when "prompt"
          "Execute prompt, output to `#{output_key}`"
        when "tool"
          tool = step["tool"] || step[:tool]
          "Call tool `#{tool}`, output to `#{output_key}`"
        when "skill"
          skill_slug = step["skill"] || step[:skill]
          "Execute skill `#{skill_slug}`, output to `#{output_key}`"
        else
          step.to_s
        end
      end

      def present?(value)
        case value
        when nil
          false
        when String
          !value.empty?
        when Array, Hash
          !value.empty?
        else
          true
        end
      end
    end
  end
end
