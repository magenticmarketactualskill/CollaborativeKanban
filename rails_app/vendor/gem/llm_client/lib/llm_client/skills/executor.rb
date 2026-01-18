# frozen_string_literal: true

module LlmClient
  module Skills
    class Executor
      attr_reader :skill, :params, :user

      # skill: SkillDefinition or any object responding to required skill methods
      # params: Hash of parameter values
      # user: Optional user context
      def initialize(skill, params = {}, user: nil)
        @skill = skill
        @params = params.transform_keys(&:to_s)
        @user = user
      end

      def call
        validate_parameters!
        apply_defaults!

        if skill.has_workflow?
          execute_workflow
        else
          execute_single_prompt
        end
      end

      private

      def validate_parameters!
        skill.required_parameters.each do |param|
          param_name = param["name"] || param[:name]
          unless @params.key?(param_name)
            raise MissingParameterError, "Missing required parameter: #{param_name}"
          end
        end
      end

      def apply_defaults!
        skill.parameters.each do |param|
          param_name = param["name"] || param[:name]
          param_default = param["default"] || param[:default]
          if param_default && !@params.key?(param_name)
            @params[param_name] = param_default
          end
        end
      end

      def execute_single_prompt
        prompt = render_template(skill.prompt_template)

        response = route_llm_request(:general, prompt)

        if response[:success] || response.respond_to?(:success?) && response.success?
          content = response[:content] || response.content rescue response[:output]
          {
            success: true,
            output: content,
            provider: response[:provider] || (response.provider rescue nil),
            model: response[:model] || (response.model rescue nil)
          }
        else
          {
            success: false,
            error: response[:error] || (response.error rescue "Unknown error")
          }
        end
      end

      def execute_workflow
        context = @params.dup

        skill.workflow_steps.each_with_index do |step, index|
          next if skip_step?(step, context)

          result = execute_step(step, context)
          output_key = step["output_key"] || step[:output_key] || "step_#{index}"
          context[output_key] = result
        end

        {
          success: true,
          output: context,
          steps_executed: skill.workflow_steps.size
        }
      rescue StandardError => e
        {
          success: false,
          error: e.message
        }
      end

      def execute_step(step, context)
        step_type = step["type"] || step[:type]
        case step_type
        when "prompt"
          execute_prompt_step(step, context)
        when "tool"
          execute_tool_step(step, context)
        when "skill"
          execute_skill_step(step, context)
        else
          raise InvalidWorkflowError, "Unknown step type: #{step_type}"
        end
      end

      def execute_prompt_step(step, context)
        prompt_template = step["prompt"] || step[:prompt]
        prompt = render_template(prompt_template, context)
        response = route_llm_request(:general, prompt)

        if response[:success] || response.respond_to?(:success?) && response.success?
          response[:content] || response.content rescue response[:output]
        else
          error = response[:error] || (response.error rescue "Unknown error")
          raise ExecutionError, "Prompt step failed: #{error}"
        end
      end

      def execute_tool_step(step, context)
        tool_name = step["tool"] || step[:tool]
        arguments = step["arguments"] || step[:arguments] || {}

        # Render argument values
        rendered_args = arguments.transform_values do |v|
          v.is_a?(String) ? render_template(v, context) : v
        end

        aggregator = Mcp::ToolAggregator.new(user_id: user&.respond_to?(:id) ? user.id : user)
        result = aggregator.call_tool(tool_name, rendered_args)

        if result.is_a?(Hash) && result.key?(:success)
          result[:success] ? result : raise(ExecutionError, "Tool step failed: #{result[:error]}")
        else
          result
        end
      end

      def execute_skill_step(step, context)
        skill_slug = step["skill"] || step[:skill]

        finder = LlmClient.configuration.skill_finder
        raise CallbackNotConfiguredError, "skill_finder" unless finder

        nested_skill = finder.call(skill_slug, user: user)
        raise ExecutionError, "Skill '#{skill_slug}' not found" unless nested_skill

        # Pass context as parameters
        skill_params = step["parameters"] || step[:parameters] || {}
        rendered_params = skill_params.transform_values do |v|
          v.is_a?(String) ? render_template(v, context) : v
        end

        executor = self.class.new(nested_skill, rendered_params, user: user)
        result = executor.call

        result[:success] ? result[:output] : raise(ExecutionError, "Skill step failed: #{result[:error]}")
      end

      def skip_step?(step, context)
        condition = step["condition"] || step[:condition]
        return false unless condition

        !evaluate_condition(condition, context)
      end

      def evaluate_condition(condition, context)
        # Simple condition evaluation: "key exists" or "key == value"
        if condition.include?("==")
          key, value = condition.split("==").map(&:strip)
          context[key].to_s == value
        elsif condition.include?("!=")
          key, value = condition.split("!=").map(&:strip)
          context[key].to_s != value
        else
          context.key?(condition.strip)
        end
      end

      def render_template(template, context = @params)
        result = template.dup

        # Replace {{key}} patterns
        result.gsub(/\{\{(\w+)\}\}/) do
          key = ::Regexp.last_match(1)
          context[key]&.to_s || ""
        end
      end

      def route_llm_request(task, prompt, schema: nil)
        router = LlmClient.configuration.llm_router
        if router
          router.call(task, prompt, schema: schema)
        else
          # Fall back to built-in router if available
          Llm::Router.route(task, prompt, schema: schema)
        end
      end
    end
  end
end
