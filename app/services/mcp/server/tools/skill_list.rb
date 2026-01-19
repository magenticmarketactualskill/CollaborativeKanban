module Mcp
  module Server
    module Tools
      class SkillList < Base
        def name
          "skill_list"
        end

        def description
          "List all available skills (reusable prompt templates and workflows)"
        end

        def input_schema
          {
            type: "object",
            properties: {
              category: {
                type: "string",
                enum: Skill::CATEGORIES,
                description: "Filter by skill category"
              },
              enabled_only: {
                type: "boolean",
                description: "Only return enabled skills (default: true)"
              }
            },
            required: []
          }
        end

        def execute(arguments, context:)
          skills = Skill.for_user(context[:user])
          skills = skills.enabled if arguments.fetch("enabled_only", true)
          skills = skills.by_category(arguments["category"]) if arguments["category"].present?

          {
            success: true,
            skills: skills.order(:category, :name).map do |skill|
              {
                slug: skill.slug,
                name: skill.name,
                description: skill.description,
                category: skill.category,
                version: skill.version,
                system_skill: skill.system_skill,
                parameters: skill.parameters.map do |p|
                  {
                    name: p["name"],
                    type: p["type"],
                    required: p["required"],
                    description: p["description"]
                  }
                end
              }
            end
          }
        end
      end
    end
  end
end
