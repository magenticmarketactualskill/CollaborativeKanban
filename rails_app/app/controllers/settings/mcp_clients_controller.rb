module Settings
  class McpClientsController < ApplicationController
    before_action :require_authentication
    before_action :set_connection, only: [ :edit, :update, :destroy, :connect, :disconnect, :refresh_capabilities ]

    def index
      @connections = McpClientConnection.for_user(current_user).order(:name)
    end

    def new
      @connection = McpClientConnection.new
    end

    def create
      @connection = McpClientConnection.new(connection_params)
      @connection.user = current_user

      if @connection.save
        respond_to do |format|
          format.html { redirect_to settings_mcp_clients_path, notice: "MCP Client connection created." }
          format.json { render json: { success: true, id: @connection.id } }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @connection.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def edit
    end

    def update
      if @connection.update(connection_params)
        respond_to do |format|
          format.html { redirect_to settings_mcp_clients_path, notice: "MCP Client connection updated." }
          format.json { render json: { success: true } }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { success: false, errors: @connection.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      LlmClient::Mcp::ConnectionManager.instance.disconnect(@connection)
      @connection.destroy

      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, notice: "MCP Client connection deleted." }
        format.json { render json: { success: true } }
      end
    end

    def connect
      LlmClient::Mcp::ConnectionManager.instance.connect(@connection)

      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, notice: "Connected to #{@connection.name}." }
        format.json { render json: { success: true, status: @connection.reload.status } }
      end
    rescue LlmClient::Mcp::ConnectionError => e
      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, alert: "Connection failed: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end

    def disconnect
      LlmClient::Mcp::ConnectionManager.instance.disconnect(@connection)

      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, notice: "Disconnected from #{@connection.name}." }
        format.json { render json: { success: true } }
      end
    end

    def refresh_capabilities
      client = LlmClient::Mcp::ConnectionManager.instance.connect(@connection)
      capabilities = client.refresh_capabilities

      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, notice: "Capabilities refreshed: #{capabilities[:tools].size} tools found." }
        format.json { render json: { success: true, capabilities: capabilities } }
      end
    rescue LlmClient::Mcp::ConnectionError, LlmClient::Mcp::NotConnectedError => e
      respond_to do |format|
        format.html { redirect_to settings_mcp_clients_path, alert: "Failed to refresh: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end

    private

    def require_authentication
      unless current_user
        redirect_to login_path, alert: "Please log in to access settings."
      end
    end

    def set_connection
      @connection = McpClientConnection.for_user(current_user).find(params[:id])
    end

    def connection_params
      params.require(:mcp_client_connection).permit(
        :name, :url, :enabled, :auth_type, :auth_token
      )
    end
  end
end
