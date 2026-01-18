class ColumnsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board
  before_action :require_board_edit_access!
  before_action :set_column, only: [:update, :destroy]

  def create
    @column = @board.columns.build(column_params)

    if @column.save
      respond_to do |format|
        format.html { redirect_to @board, notice: 'Column created.' }
        format.turbo_stream
      end
    else
      redirect_to @board, alert: @column.errors.full_messages.join(', ')
    end
  end

  def update
    if @column.update(column_params)
      respond_to do |format|
        format.html { redirect_to @board, notice: 'Column updated.' }
        format.turbo_stream
      end
    else
      redirect_to @board, alert: @column.errors.full_messages.join(', ')
    end
  end

  def destroy
    @column.destroy
    respond_to do |format|
      format.html { redirect_to @board, notice: 'Column deleted.' }
      format.turbo_stream
    end
  end

  def reorder
    params[:column_ids].each_with_index do |id, index|
      @board.columns.find(id).update(position: index)
    end
    head :ok
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_column
    @column = @board.columns.find(params[:id])
  end

  def column_params
    params.require(:column).permit(:name, :position)
  end
end
