class LlmConfigurationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_llm_configuration, only: [:show, :edit, :update, :destroy, :test_connection, :set_default]

  def index
    @llm_configurations = LlmConfiguration.for_user(current_user).by_priority
  end

  def show
  end

  def new
    @llm_configuration = LlmConfiguration.new(user_id: current_user.id)
  end

  def edit
  end

  def create
    @llm_configuration = LlmConfiguration.new(llm_configuration_params)
    @llm_configuration.user = current_user

    if @llm_configuration.save
      redirect_to llm_configurations_path, notice: "LLM configuration was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    update_params = llm_configuration_params
    update_params = update_params.except(:api_key) if update_params[:api_key].blank?

    if @llm_configuration.update(update_params)
      redirect_to llm_configurations_path, notice: "LLM configuration was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @llm_configuration.destroy
    redirect_to llm_configurations_path, notice: "LLM configuration was successfully deleted."
  end

  def test_connection
    result = @llm_configuration.test_connection
    render json: result
  end

  def set_default
    @llm_configuration.update(default_for_type: true)
    redirect_to llm_configurations_path, notice: "#{@llm_configuration.name} is now the default for #{@llm_configuration.provider_type}."
  end

  private

  def set_llm_configuration
    @llm_configuration = LlmConfiguration.for_user(current_user).find(params[:id])
  end

  def llm_configuration_params
    params.require(:llm_configuration).permit(
      :name,
      :provider_type,
      :endpoint,
      :model,
      :api_key,
      :active,
      :default_for_type,
      :priority,
      :cost_per_input_token,
      :cost_per_output_token,
      :speed_rating,
      options: {}
    )
  end
end
