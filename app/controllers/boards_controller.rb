class BoardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_board_access!, only: [:show, :edit, :update, :destroy]
  before_action :require_board_admin_access!, only: [:edit, :update]

  def index
    @boards = current_user.all_boards.includes(:owner, :members).order(updated_at: :desc)
    @boards_by_level = @boards.group_by(&:level)
  end

  def show
    @columns = @board.columns.includes(cards: :assignees)
    @members = [@board.owner] + @board.members.to_a
  end

  def new
    @board = Board.new
  end

  def create
    @board = current_user.owned_boards.build(board_params)

    if @board.save
      redirect_to @board, notice: 'Board created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @board.update(board_params)
      redirect_to @board, notice: 'Board updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @board.owner_id == current_user.id
      @board.destroy
      redirect_to boards_path, notice: 'Board deleted successfully.'
    else
      redirect_to @board, alert: 'Only the owner can delete this board.'
    end
  end

  private

  def board_params
    params.require(:board).permit(:name, :description, :level)
  end
end
