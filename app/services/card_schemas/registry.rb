# frozen_string_literal: true

module CardSchemas
  class Registry
    include Singleton

    BUILT_IN_TYPES = %w[task checklist bug milestone].freeze

    def initialize
      @schemas = {}
      @mutex = Mutex.new
      load_built_in_schemas
    end

    def register(type, schema)
      @mutex.synchronize do
        @schemas[type.to_s] = schema
      end
    end

    def get(type)
      @schemas[type.to_s]
    end

    def [](type)
      get(type)
    end

    def all
      @schemas.dup
    end

    def types
      @schemas.keys
    end

    def valid_type?(type)
      @schemas.key?(type.to_s)
    end

    def default_type
      "task"
    end

    def schema_for_card(card)
      get(card.card_type) || get(default_type)
    end

    def component_class_for(type)
      schema = get(type)
      return Cards::TaskCardComponent unless schema

      schema.component_class
    end

    def reload!
      @mutex.synchronize do
        @schemas.clear
        load_built_in_schemas
        load_custom_schemas
      end
    end

    private

    def load_built_in_schemas
      schema_path = Rails.root.join("config", "card_schemas")
      return unless schema_path.exist?

      BUILT_IN_TYPES.each do |type|
        file_path = schema_path.join("#{type}.yml")
        next unless File.exist?(file_path)

        config = YAML.safe_load_file(file_path, symbolize_names: true)
        schema = BaseSchema.from_config(type, config)
        register(type, schema)
      end
    end

    def load_custom_schemas
      return unless defined?(CardSchema) && CardSchema.respond_to?(:active)

      CardSchema.active.find_each do |record|
        schema = BaseSchema.from_config(record.type_name, record.schema_config.deep_symbolize_keys)
        register(record.type_name, schema)
      end
    rescue ActiveRecord::StatementInvalid
      # Table doesn't exist yet (migrations haven't run)
      nil
    end
  end
end
