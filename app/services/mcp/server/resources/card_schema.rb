module Mcp
  module Server
    module Resources
      class CardSchema < Base
        def name
          "card-schema"
        end

        def uri_template
          "kanban://schemas/card/{card_type}"
        end

        def description
          "JSON schema for a specific card type (task, checklist, bug, milestone)"
        end

        def read(uri, context:)
          params = extract_params(uri)
          card_type = params[:card_type]

          schema = CardSchemas::Registry.instance.schema_for(card_type)

          {
            uri: uri,
            mimeType: mime_type,
            text: schema.to_json_schema.to_json
          }
        rescue StandardError => e
          {
            uri: uri,
            mimeType: "text/plain",
            text: "Error loading schema: #{e.message}"
          }
        end
      end
    end
  end
end
