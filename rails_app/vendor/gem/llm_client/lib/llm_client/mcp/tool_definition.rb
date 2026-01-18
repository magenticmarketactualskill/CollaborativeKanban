# frozen_string_literal: true

module LlmClient
  module Mcp
    class ToolDefinition
      attr_reader :name, :description, :input_schema, :source, :connection

      def initialize(name:, description: nil, input_schema: nil, inputSchema: nil, source: :external, connection: nil, **_extras)
        @name = name
        @description = description
        @input_schema = input_schema || inputSchema || {}
        @source = source
        @connection = connection
      end

      def local?
        source == :local
      end

      def external?
        source == :external
      end

      def full_name
        if external? && connection
          connection_name = connection.respond_to?(:name) ? connection.name : connection.to_s
          "#{connection_name}/#{name}"
        else
          name
        end
      end

      def to_llm_tool_definition
        {
          name: full_name,
          description: description,
          input_schema: input_schema
        }
      end

      def to_h
        {
          name: name,
          description: description,
          inputSchema: input_schema
        }
      end
    end
  end
end
