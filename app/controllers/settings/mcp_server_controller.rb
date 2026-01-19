module Settings
  class McpServerController < ApplicationController
    before_action :require_authentication
    before_action :set_configuration

    def show
      @available_tools = Mcp::Server::ToolRegistry.instance.all
      @available_resources = Mcp::Server::ResourceRegistry.instance.list
    end

    def update
      if @configuration.update(mcp_server_params)
        respond_to do |format|
          format.html { redirect_to settings_mcp_server_path, notice: "MCP Server configuration saved." }
          format.json { render json: { success: true } }
        end
      else
        respond_to do |format|
          format.html { render :show, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @configuration.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def test_connection
      if @configuration.enabled
        result = {
          success: true,
          message: "MCP Server is configured and ready",
          tools_count: Mcp::Server::ToolRegistry.instance.all.size,
          resources_count: Mcp::Server::ResourceRegistry.instance.list.size
        }
      else
        result = { success: false, message: "MCP Server is disabled" }
      end

      render json: result
    end

    private

    def require_authentication
      unless current_user
        redirect_to login_path, alert: "Please log in to access settings."
      end
    end

    def set_configuration
      @configuration = McpServerConfiguration.for_user(current_user).first_or_initialize(
        name: "Default",
        user: current_user,
        enabled: true
      )
      @configuration.save if @configuration.new_record?
    end

    def mcp_server_params
      params.require(:mcp_server_configuration).permit(
        :enabled, :port, :auth_type, :auth_token,
        enabled_tools: [], enabled_resources: []
      )
    end
  end
end
