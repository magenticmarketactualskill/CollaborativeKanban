# frozen_string_literal: true

module CardSchemas
  class BaseSchema
    attr_reader :type_name, :display_name, :icon, :color, :fields,
                :validations, :component_class_name, :keywords

    def initialize(type_name:, config:)
      @type_name = type_name
      @display_name = config[:display_name] || type_name.titleize
      @icon = config[:icon] || "document"
      @color = config[:color] || "gray"
      @fields = build_fields(config[:fields] || [])
      @validations = config[:validations] || {}
      @component_class_name = config[:component_class] || "Cards::#{type_name.camelize}CardComponent"
      @keywords = config[:keywords] || []
    end

    def self.from_config(type_name, config)
      new(type_name: type_name, config: config)
    end

    def component_class
      @component_class_name.constantize
    rescue NameError
      Cards::BaseCardComponent
    end

    def field(name)
      fields.find { |f| f.name == name.to_s }
    end

    def required_fields
      fields.select(&:required?)
    end

    def optional_fields
      fields.reject(&:required?)
    end

    def metadata_fields
      fields.select(&:metadata?)
    end

    def validate_metadata(metadata)
      errors = []

      required_fields.each do |field|
        unless metadata.key?(field.name) || metadata.key?(field.name.to_sym)
          errors << "#{field.display_name} is required"
        end
      end

      fields.each do |field|
        value = metadata[field.name] || metadata[field.name.to_sym]
        next if value.nil? && !field.required?

        field_errors = field.validate(value)
        errors.concat(field_errors)
      end

      errors
    end

    def to_json_schema
      {
        type: "object",
        properties: fields.each_with_object({}) { |f, h| h[f.name] = f.to_json_schema },
        required: required_fields.map(&:name)
      }
    end

    def default_metadata
      fields.each_with_object({}) do |field, hash|
        hash[field.name] = field.default unless field.default.nil?
      end
    end

    private

    def build_fields(field_configs)
      field_configs.map { |config| SchemaField.new(config) }
    end
  end
end
