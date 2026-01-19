module Mcp
  module Server
    module Tools
      class SkillExecute < Base
        def name
          "skill_execute"
        end

        def description
          "Execute a skill (reusable prompt template or workflow) with the provided parameters"
        end

        def input_schema
          {
            type: "object",
            properties: {
              skill_slug: { type: "string", description: "The slug identifier of the skill to execute" },
              parameters: { type: "object", description: "Parameters to pass to the skill template" }
            },
            required: %w[skill_slug]
          }
        end

        def execute(arguments, context:)
          skill = Skill.enabled.for_user(context[:user]).find_by!(slug: arguments["skill_slug"])
          params = arguments["parameters"] || {}

          result = skill.execute(params)

          {
            success: true,
            skill: skill.slug,
            result: result
          }
        rescue ActiveRecord::RecordNotFound
          {
            success: false,
            error: "Skill not found: #{arguments['skill_slug']}"
          }
        rescue Skills::MissingParameterError => e
          {
            success: false,
            error: e.message
          }
        rescue StandardError => e
          {
            success: false,
            error: e.message
          }
        end
      end
    end
  end
end
