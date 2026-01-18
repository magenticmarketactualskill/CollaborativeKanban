module Settings
  class RoutingController < ApplicationController
    before_action :require_authentication

    def show
      @routing_table = Llm::Router::ROUTING_TABLE
      @recent_llm_calls = LlmCall.recent.includes(:llm_configuration).limit(20)
      @recent_mcp_calls = McpToolCall.recent.includes(:mcp_client_connection).limit(20)
      @statistics = calculate_statistics
      @provider_status = check_provider_status
    end

    def activity
      @llm_calls = filtered_llm_calls.limit(50)
      @mcp_calls = filtered_mcp_calls.limit(50)

      respond_to do |format|
        format.html { render partial: "activity_results", locals: { llm_calls: @llm_calls, mcp_calls: @mcp_calls } }
        format.turbo_stream
      end
    end

    def statistics
      @statistics = calculate_statistics
      render json: @statistics
    end

    private

    def require_authentication
      redirect_to login_path, alert: "Please log in to access settings." unless current_user
    end

    def filtered_llm_calls
      scope = LlmCall.recent.includes(:llm_configuration, :llm_stages)
      scope = scope.for_task(params[:task_type]) if params[:task_type].present?
      scope = scope.for_provider(params[:provider]) if params[:provider].present?
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where("created_at >= ?", parse_date_filter) if params[:date_from].present?
      scope
    end

    def filtered_mcp_calls
      scope = McpToolCall.order(created_at: :desc).includes(:mcp_client_connection)
      scope = scope.where(direction: params[:direction]) if params[:direction].present?
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where("tool_name LIKE ?", "%#{params[:tool_name]}%") if params[:tool_name].present?
      scope
    end

    def calculate_statistics
      time_range = 24.hours.ago..Time.current

      llm_calls = LlmCall.where(created_at: time_range)
      mcp_calls = McpToolCall.where(created_at: time_range)

      {
        llm: {
          total: llm_calls.count,
          completed: llm_calls.completed.count,
          failed: llm_calls.failed.count,
          success_rate: calculate_success_rate(llm_calls),
          avg_latency: llm_calls.completed.average(:latency_ms)&.round || 0,
          by_task_type: llm_calls.group(:task_type).count,
          by_provider: llm_calls.group(:provider).count,
          total_tokens: llm_calls.sum(:input_tokens).to_i + llm_calls.sum(:output_tokens).to_i
        },
        mcp: {
          total: mcp_calls.count,
          successful: mcp_calls.successful.count,
          failed: mcp_calls.failed.count,
          success_rate: calculate_mcp_success_rate(mcp_calls),
          avg_latency: mcp_calls.successful.average(:latency_ms)&.round || 0,
          by_tool: mcp_calls.group(:tool_name).count,
          by_direction: mcp_calls.group(:direction).count
        }
      }
    end

    def check_provider_status
      {
        ollama: Llm::Router.ollama_available?,
        claude: Llm::Router.claude_available?
      }
    rescue StandardError
      { ollama: false, claude: false }
    end

    def calculate_success_rate(calls)
      return 0 if calls.count.zero?
      ((calls.completed.count.to_f / calls.count) * 100).round(1)
    end

    def calculate_mcp_success_rate(calls)
      return 0 if calls.count.zero?
      ((calls.successful.count.to_f / calls.count) * 100).round(1)
    end

    def parse_date_filter
      Time.zone.parse(params[:date_from])
    rescue StandardError
      24.hours.ago
    end
  end
end
