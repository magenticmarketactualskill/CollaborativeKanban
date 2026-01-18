module Skills
  class Executor
    def initialize(skill, params = {}, llm_config: nil)
      @skill = skill
      @params = params.transform_keys(&:to_s)
      @llm_config = llm_config
    end

    def call
      validate_parameters!
      apply_defaults!

      if @skill.has_workflow?
        execute_workflow
      else
        execute_single_prompt
      end
    end

    private

    def validate_parameters!
      @skill.required_parameters.each do |param|
        unless @params.key?(param["name"])
          raise MissingParameterError, "Missing required parameter: #{param['name']}"
        end
      end
    end

    def apply_defaults!
      @skill.parameters.each do |param|
        if param["default"] && !@params.key?(param["name"])
          @params[param["name"]] = param["default"]
        end
      end
    end

    def execute_single_prompt
      prompt = render_template(@skill.prompt_template)

      response = Llm::Router.route(:general, prompt)

      if response.success?
        {
          success: true,
          output: response.content,
          provider: response.provider,
          model: response.model
        }
      else
        {
          success: false,
          error: response.error
        }
      end
    end

    def execute_workflow
      context = @params.dup

      @skill.workflow_steps.each_with_index do |step, index|
        next if skip_step?(step, context)

        result = execute_step(step, context)
        output_key = step["output_key"] || "step_#{index}"
        context[output_key] = result
      end

      {
        success: true,
        output: context,
        steps_executed: @skill.workflow_steps.size
      }
    rescue StandardError => e
      {
        success: false,
        error: e.message
      }
    end

    def execute_step(step, context)
      case step["type"]
      when "prompt"
        execute_prompt_step(step, context)
      when "tool"
        execute_tool_step(step, context)
      when "skill"
        execute_skill_step(step, context)
      else
        raise InvalidWorkflowError, "Unknown step type: #{step['type']}"
      end
    end

    def execute_prompt_step(step, context)
      prompt = render_template(step["prompt"], context)
      response = Llm::Router.route(:general, prompt)

      if response.success?
        response.content
      else
        raise ExecutionError, "Prompt step failed: #{response.error}"
      end
    end

    def execute_tool_step(step, context)
      tool_name = step["tool"]
      arguments = step["arguments"] || {}

      # Render argument values
      rendered_args = arguments.transform_values do |v|
        v.is_a?(String) ? render_template(v, context) : v
      end

      aggregator = Mcp::Client::ToolAggregator.new
      result = aggregator.call_tool(tool_name, rendered_args)

      result[:success] ? result : raise(ExecutionError, "Tool step failed: #{result[:error]}")
    end

    def execute_skill_step(step, context)
      skill_slug = step["skill"]
      skill = Skill.enabled.find_by!(slug: skill_slug)

      # Pass context as parameters
      skill_params = step["parameters"] || {}
      rendered_params = skill_params.transform_values do |v|
        v.is_a?(String) ? render_template(v, context) : v
      end

      result = skill.execute(rendered_params)

      result[:success] ? result[:output] : raise(ExecutionError, "Skill step failed: #{result[:error]}")
    end

    def skip_step?(step, context)
      return false unless step["condition"]

      condition = step["condition"]
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
        key = $1
        context[key]&.to_s || ""
      end
    end
  end

  class MissingParameterError < StandardError; end
  class InvalidWorkflowError < StandardError; end
  class ExecutionError < StandardError; end
end
