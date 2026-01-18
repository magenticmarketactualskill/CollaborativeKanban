# frozen_string_literal: true

require "yaml"

module LlmClient
  module Skills
    class Importer
      FRONTMATTER_REGEX = /\A---\n(.+?)\n---\n?(.*)/m
      CATEGORIES = SkillDefinition::CATEGORIES

      attr_reader :content, :filename

      def initialize(content, filename: nil)
        @content = content
        @filename = filename
      end

      def import
        frontmatter, body = parse_markdown

        SkillDefinition.new(
          name: frontmatter["name"] || extract_name_from_filename,
          slug: frontmatter["slug"] || generate_slug(frontmatter["name"] || extract_name_from_filename),
          version: frontmatter["version"] || "1.0.0",
          description: frontmatter["description"],
          category: normalize_category(frontmatter["category"]),
          parameters: normalize_parameters(frontmatter["parameters"] || []),
          prompt_template: extract_prompt_template(body, frontmatter),
          workflow_steps: normalize_workflow(frontmatter["workflow"] || []),
          dependencies: frontmatter["dependencies"] || [],
          metadata: extract_metadata(frontmatter),
          source: "imported",
          source_file: filename
        )
      end

      def valid?
        import
        true
      rescue StandardError
        false
      end

      private

      def parse_markdown
        match = content.match(FRONTMATTER_REGEX)
        raise InvalidFormatError, "Invalid skill file format - missing YAML frontmatter" unless match

        frontmatter = YAML.safe_load(match[1], permitted_classes: [Symbol, Date, Time])
        raise InvalidFormatError, "Frontmatter must be a hash" unless frontmatter.is_a?(Hash)

        body = match[2].strip

        [frontmatter, body]
      rescue Psych::SyntaxError => e
        raise InvalidFormatError, "Invalid YAML in frontmatter: #{e.message}"
      end

      def normalize_parameters(params)
        return [] unless params.is_a?(Array)

        params.map do |p|
          next nil unless p.is_a?(Hash)

          {
            "name" => p["name"].to_s,
            "type" => p["type"] || "string",
            "description" => p["description"],
            "required" => p["required"] == true,
            "default" => p["default"]
          }.compact
        end.compact
      end

      def normalize_workflow(steps)
        return [] unless steps.is_a?(Array)

        steps.map do |step|
          next nil unless step.is_a?(Hash)

          {
            "type" => step["type"],
            "prompt" => step["prompt"],
            "tool" => step["tool"],
            "skill" => step["skill"],
            "arguments" => step["arguments"],
            "parameters" => step["parameters"],
            "output_key" => step["output_key"] || step["output"],
            "condition" => step["condition"]
          }.compact
        end.compact
      end

      def normalize_category(category)
        return nil unless category
        category = category.to_s.downcase
        CATEGORIES.include?(category) ? category : nil
      end

      def extract_prompt_template(body, frontmatter)
        # Check if prompt is directly in frontmatter
        return frontmatter["prompt"] if frontmatter["prompt"] && !frontmatter["prompt"].empty?

        # Look for ```prompt block in body
        prompt_match = body.match(/```prompt\n(.+?)```/m)
        return prompt_match[1].strip if prompt_match

        # Look for ## Prompt section
        section_match = body.match(/##\s*Prompt\s*\n+(.+?)(?=\n##|\z)/m)
        if section_match
          section = section_match[1].strip
          # Check for code block within section
          code_match = section.match(/```\w*\n(.+?)```/m)
          return code_match ? code_match[1].strip : section
        end

        # Fallback to entire body
        body && !body.empty? ? body : "{{input}}"
      end

      def extract_metadata(frontmatter)
        %w[author tags license homepage repository].each_with_object({}) do |key, hash|
          hash[key] = frontmatter[key] if frontmatter[key]
        end
      end

      def extract_name_from_filename
        return nil unless filename
        # Remove extension and convert to title case
        base = File.basename(filename, ".*")
        base.gsub(/[-_]/, " ").split.map(&:capitalize).join(" ")
      end

      def generate_slug(name)
        return nil unless name
        name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
      end
    end
  end
end
