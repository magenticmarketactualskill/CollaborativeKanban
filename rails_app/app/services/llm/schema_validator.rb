# frozen_string_literal: true

require "json_schemer"

module Llm
  class SchemaValidator
    SCHEMAS_PATH = Rails.root.join("app/services/llm/schemas")

    class ValidationError < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("Schema validation failed: #{errors.map { |e| e["error"] }.join(", ")}")
      end
    end

    class << self
      def validate(data, schema_name)
        schema = load_schema(schema_name)
        schemer = JSONSchemer.schema(schema)
        errors = schemer.validate(data).to_a

        if errors.empty?
          ValidationResult.new(valid: true, data: data)
        else
          ValidationResult.new(valid: false, errors: format_errors(errors))
        end
      end

      def validate!(data, schema_name)
        result = validate(data, schema_name)
        raise ValidationError, result.errors unless result.valid?

        result
      end

      def valid?(data, schema_name)
        validate(data, schema_name).valid?
      end

      def schema_for(schema_name)
        load_schema(schema_name)
      end

      private

      def load_schema(schema_name)
        @schemas ||= {}
        @schemas[schema_name] ||= begin
          path = SCHEMAS_PATH.join("#{schema_name}.json")
          raise ArgumentError, "Schema not found: #{schema_name}" unless File.exist?(path)

          JSON.parse(File.read(path))
        end
      end

      def format_errors(errors)
        errors.map do |error|
          {
            "path" => error["data_pointer"],
            "error" => error["type"],
            "details" => error["details"] || error["error"]
          }
        end
      end
    end

    class ValidationResult
      attr_reader :data, :errors

      def initialize(valid:, data: nil, errors: [])
        @valid = valid
        @data = data
        @errors = errors
      end

      def valid?
        @valid
      end

      def invalid?
        !@valid
      end

      def error_messages
        errors.map { |e| "#{e["path"]}: #{e["error"]}" }
      end
    end
  end
end
