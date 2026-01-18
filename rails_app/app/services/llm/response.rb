# frozen_string_literal: true

module Llm
  class Response
    attr_reader :content, :model, :provider, :latency, :error

    def initialize(content:, provider:, model: nil, latency: nil, error: nil, success: true)
      @content = content
      @model = model
      @provider = provider
      @latency = latency
      @error = error
      @success = success
    end

    def success?
      @success && content.present?
    end

    def failure?
      !success?
    end

    def to_h
      {
        content: content,
        model: model,
        provider: provider,
        latency: latency,
        error: error,
        success: success?
      }
    end

    # Parse JSON content safely
    def parsed_json
      return nil unless success?

      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    # Parse and validate JSON against a schema
    # Returns ValidationResult with valid?, data, and errors
    def validated_json(schema_name)
      json = parsed_json
      return SchemaValidator::ValidationResult.new(valid: false, errors: [{ "error" => "Invalid JSON" }]) unless json

      SchemaValidator.validate(json, schema_name)
    end

    # Parse and validate JSON, returning data or nil
    def validated_json!(schema_name)
      result = validated_json(schema_name)
      result.valid? ? result.data : nil
    end

    # Check if parsed JSON conforms to schema
    def valid_json?(schema_name)
      json = parsed_json
      return false unless json

      SchemaValidator.valid?(json, schema_name)
    end

    # Extract content between markers
    def extract(start_marker, end_marker = nil)
      return nil unless success?

      if end_marker
        match = content.match(/#{Regexp.escape(start_marker)}(.+?)#{Regexp.escape(end_marker)}/m)
        match&.[](1)&.strip
      else
        content.split(start_marker).last&.strip
      end
    end

    # Convert to dry-monads Result for TaskFrame integration
    def to_result
      if success?
        Dry::Monads::Success(self)
      else
        Dry::Monads::Failure(error: error, provider: provider)
      end
    end
  end
end
