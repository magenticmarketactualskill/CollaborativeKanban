class BoardMembersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board
  before_action :require_board_admin_access!
  before_action :set_member, only: [:update, :destroy]

  def index
    @members = @board.board_members.includes(:user)
    @available_users = User.where.not(id: [@board.owner_id] + @board.members.pluck(:id))
  end

  def create
    @member = @board.board_members.build(member_params)

    if @member.save
      respond_to do |format|
        format.html { redirect_to board_board_members_path(@board), notice: 'Member added.' }
        format.turbo_stream
      end
    else
      redirect_to board_board_members_path(@board), alert: @member.errors.full_messages.join(', ')
    end
  end

  def update
    if @member.update(member_params)
      respond_to do |format|
        format.html { redirect_to board_board_members_path(@board), notice: 'Member role updated.' }
        format.turbo_stream
      end
    else
      redirect_to board_board_members_path(@board), alert: @member.errors.full_messages.join(', ')
    end
  end

  def destroy
    @member.destroy
    respond_to do |format|
      format.html { redirect_to board_board_members_path(@board), notice: 'Member removed.' }
      format.turbo_stream
    end
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_member
    @member = @board.board_members.find(params[:id])
  end

  def member_params
    params.require(:board_member).permit(:user_id, :role)
  end
end
