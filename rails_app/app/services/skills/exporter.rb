module Skills
  class Exporter
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
      "#{@skill.slug}.md"
    end

    private

    def build_frontmatter
      fm = {
        "name" => @skill.name,
        "slug" => @skill.slug,
        "version" => @skill.version
      }

      fm["description"] = @skill.description if @skill.description.present?
      fm["category"] = @skill.category if @skill.category.present?
      fm["parameters"] = @skill.parameters if @skill.parameters.present?
      fm["workflow"] = @skill.workflow_steps if @skill.workflow_steps.present?
      fm["dependencies"] = @skill.dependencies if @skill.dependencies.present?
      fm.merge!(@skill.metadata) if @skill.metadata.present?

      fm
    end

    def build_body
      parts = []

      parts << "# #{@skill.name}"

      if @skill.description.present?
        parts << ""
        parts << @skill.description
      end

      parts << ""
      parts << "## Prompt"
      parts << ""
      parts << "```prompt"
      parts << @skill.prompt_template
      parts << "```"

      if @skill.parameters.present?
        parts << ""
        parts << "## Parameters"
        parts << ""
        @skill.parameters.each do |p|
          required = p["required"] ? " (required)" : ""
          default = p["default"] ? " [default: #{p['default']}]" : ""
          parts << "- **#{p['name']}** (`#{p['type']}`#{required}#{default}): #{p['description']}"
        end
      end

      if @skill.workflow_steps.present?
        parts << ""
        parts << "## Workflow"
        parts << ""
        @skill.workflow_steps.each_with_index do |step, i|
          parts << "#{i + 1}. **#{step['type']}**: #{step_description(step)}"
        end
      end

      parts.join("\n")
    end

    def step_description(step)
      case step["type"]
      when "prompt"
        "Execute prompt, output to `#{step['output_key']}`"
      when "tool"
        "Call tool `#{step['tool']}`, output to `#{step['output_key']}`"
      when "skill"
        "Execute skill `#{step['skill']}`, output to `#{step['output_key']}`"
      else
        step.to_s
      end
    end
  end
end
