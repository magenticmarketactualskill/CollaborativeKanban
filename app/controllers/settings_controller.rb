class SettingsController < ApplicationController
  before_action :require_authentication

  def update
    @user_setting = current_user.user_setting || current_user.build_user_setting

    if @user_setting.update(user_setting_params)
      redirect_back fallback_location: root_path, notice: "Settings saved successfully."
    else
      redirect_back fallback_location: root_path, alert: "Failed to save settings: #{@user_setting.errors.full_messages.join(', ')}"
    end
  end

  def test_connection
    @user_setting = current_user.user_setting || current_user.build_user_setting
    @user_setting.assign_attributes(user_setting_params)

    result = @user_setting.test_connection

    render json: result
  end

  private

  def user_setting_params
    params.require(:user_setting).permit(
      :local_endpoint,
      :local_model,
      :local_api_key,
      :remote_provider,
      :remote_api_key,
      :remote_endpoint,
      :remote_model,
      :active_provider
    )
  end
end
