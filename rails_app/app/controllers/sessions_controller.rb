class SessionsController < ApplicationController
  def new
    redirect_to boards_path if user_signed_in?
  end

  def create
    user = User.find_by(email: params[:email])

    if user
      session[:user_id] = user.id
      user.update(last_signed_in_at: Time.current)
      redirect_to boards_path, notice: 'Signed in successfully.'
    else
      flash.now[:alert] = 'Invalid email address.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: 'Signed out successfully.'
  end
end
