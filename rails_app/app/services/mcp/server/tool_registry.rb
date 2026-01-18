module Mcp
  module Server
    class ToolRegistry
      include Singleton

      def initialize
        @tools = {}
      end

      def register(tool)
        @tools[tool.name] = tool
      end

      def unregister(tool_name)
        @tools.delete(tool_name)
      end

      def tool(name)
        @tools[name]
      end

      def all
        @tools.values
      end

      def list(config = nil)
        tools = all
        tools = tools.select { |t| config.tool_enabled?(t.name) } if config
        tools.map(&:to_definition)
      end

      def clear!
        @tools = {}
      end

      def register_defaults!
        clear!
        register(Tools::CardCreate.new)
        register(Tools::CardRead.new)
        register(Tools::CardUpdate.new)
        register(Tools::CardDelete.new)
        register(Tools::CardAnalyze.new)
        register(Tools::CardSuggestions.new)
        register(Tools::BoardList.new)
        register(Tools::BoardRead.new)
        register(Tools::LlmRoute.new)
        register(Tools::SkillExecute.new)
        register(Tools::SkillList.new)
      end
    end
  end
end
