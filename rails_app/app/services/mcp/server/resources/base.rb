module Mcp
  module Server
    module Resources
      class Base
        def name
          raise NotImplementedError
        end

        def uri_template
          raise NotImplementedError
        end

        def description
          raise NotImplementedError
        end

        def mime_type
          "application/json"
        end

        def read(uri, context:)
          raise NotImplementedError
        end

        def matches?(uri)
          pattern = uri_template.gsub(/\{[^}]+\}/, "[^/]+")
          uri.match?(/\A#{pattern}\z/)
        end

        def to_definition
          {
            uri: uri_template,
            name: name,
            description: description,
            mimeType: mime_type
          }
        end

        protected

        def extract_params(uri)
          pattern = uri_template.gsub(/\{([^}]+)\}/, "(?<\\1>[^/]+)")
          match = uri.match(/\A#{pattern}\z/)
          match ? match.named_captures.transform_keys(&:to_sym) : {}
        end
      end
    end
  end
end
