module Mcp
  module Server
    module Resources
      class SkillDefinition < Base
        def name
          "skill-definition"
        end

        def uri_template
          "kanban://skills/{skill_slug}"
        end

        def description
          "Full skill definition in markdown format"
        end

        def mime_type
          "text/markdown"
        end

        def read(uri, context:)
          params = extract_params(uri)
          skill_slug = params[:skill_slug]

          skill = Skill.for_user(context[:user]).find_by!(slug: skill_slug)

          {
            uri: uri,
            mimeType: mime_type,
            text: skill.to_markdown
          }
        rescue ActiveRecord::RecordNotFound
          {
            uri: uri,
            mimeType: "text/plain",
            text: "Skill not found: #{skill_slug}"
          }
        end
      end
    end
  end
end
