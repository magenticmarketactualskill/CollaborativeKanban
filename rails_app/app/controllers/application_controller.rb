class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :current_user, :user_signed_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      redirect_to login_path, alert: 'You must be signed in to access this page.'
    end
  end

  def require_board_access!
    @board = Board.find(params[:board_id] || params[:id])
    unless @board.owner_id == current_user.id || @board.members.include?(current_user)
      redirect_to boards_path, alert: 'You do not have access to this board.'
    end
  end

  def require_board_edit_access!
    require_board_access!
    unless @board.user_can_edit?(current_user)
      redirect_to board_path(@board), alert: 'You do not have permission to edit this board.'
    end
  end

  def require_board_admin_access!
    require_board_access!
    unless @board.user_can_admin?(current_user)
      redirect_to board_path(@board), alert: 'You do not have admin permissions for this board.'
    end
  end
end
