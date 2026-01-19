# frozen_string_literal: true

module CardSchemas
  class SchemaField
    attr_reader :name, :display_name, :type, :default, :options, :validations

    def initialize(config)
      @name = config[:name].to_s
      @display_name = config[:display_name] || @name.titleize
      @type = config[:type] || "string"
      @default = config[:default]
      @required = config.fetch(:required, false)
      @metadata = config.fetch(:metadata, true)
      @options = config[:options] || []
      @validations = config[:validations] || {}
    end

    def required?
      @required
    end

    def metadata?
      @metadata
    end

    def validate(value)
      errors = []

      case type
      when "string"
        errors << "#{display_name} must be a string" unless value.nil? || value.is_a?(String)
      when "integer"
        errors << "#{display_name} must be a number" unless value.nil? || value.is_a?(Integer)
      when "boolean"
        errors << "#{display_name} must be true or false" unless value.nil? || [true, false].include?(value)
      when "array"
        errors << "#{display_name} must be a list" unless value.nil? || value.is_a?(Array)
      when "select"
        errors << "#{display_name} must be one of: #{options.join(', ')}" unless value.nil? || options.include?(value)
      end

      if validations[:min_length] && value.respond_to?(:length) && value.length < validations[:min_length]
        errors << "#{display_name} is too short (minimum #{validations[:min_length]} characters)"
      end

      if validations[:max_length] && value.respond_to?(:length) && value.length > validations[:max_length]
        errors << "#{display_name} is too long (maximum #{validations[:max_length]} characters)"
      end

      errors
    end

    def to_json_schema
      base = { description: display_name }

      case type
      when "string" then base.merge(type: "string")
      when "integer" then base.merge(type: "integer")
      when "boolean" then base.merge(type: "boolean")
      when "array" then base.merge(type: "array", items: { type: "string" })
      when "select" then base.merge(type: "string", enum: options)
      else base.merge(type: "string")
      end
    end
  end
end
