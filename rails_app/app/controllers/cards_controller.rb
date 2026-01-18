class CardsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board
  before_action :require_board_access!
  before_action :require_board_edit_access!, except: [:show]
  before_action :set_card, only: [:show, :edit, :update, :destroy, :move, :assign, :unassign, :analyze, :infer_type, :suggestions]

  def show
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    @column = @board.columns.find(params[:column_id])
    @card = @column.cards.build
  end

  def create
    @column = @board.columns.find(params[:column_id])
    @card = @column.cards.build(card_params)
    @card.board = @board
    @card.created_by = current_user

    if @card.save
      respond_to do |format|
        format.html { redirect_to @board, notice: 'Card created.' }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @card.update(card_params)
      respond_to do |format|
        format.html { redirect_to @board, notice: 'Card updated.' }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @column = @card.column
    @card.destroy
    respond_to do |format|
      format.html { redirect_to @board, notice: 'Card deleted.' }
      format.turbo_stream
    end
  end

  def move
    new_column = @board.columns.find(params[:column_id])
    new_position = params[:position].to_i

    @card.move_to(new_column, new_position)

    respond_to do |format|
      format.html { redirect_to @board }
      format.json { render json: { success: true } }
      format.turbo_stream
    end
  end

  def assign
    user = User.find(params[:user_id])
    @card.assignees << user unless @card.assignees.include?(user)

    respond_to do |format|
      format.html { redirect_to @board }
      format.turbo_stream
    end
  end

  def unassign
    user = User.find(params[:user_id])
    @card.assignees.delete(user)

    respond_to do |format|
      format.html { redirect_to @board }
      format.turbo_stream
    end
  end

  def analyze
    CardAnalysisJob.perform_later(@card.id)

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Analysis started.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "card-#{@card.id}-analysis",
          partial: "cards/analysis_loading"
        )
      end
      format.json { render json: { status: 'analyzing' } }
    end
  end

  def infer_type
    CardTypeInferenceJob.perform_later(@card.id)

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Type inference started.' }
      format.turbo_stream
      format.json { render json: { status: 'inferring' } }
    end
  end

  def suggestions
    SuggestionGenerationJob.perform_later(@card.id)

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Generating suggestions.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "card-#{@card.id}-suggestions",
          partial: "cards/suggestions_loading"
        )
      end
      format.json { render json: { status: 'generating' } }
    end
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_card
    @card = @board.cards.find(params[:id])
  end

  def card_params
    params.require(:card).permit(:title, :description, :priority, :due_date, :column_id, :card_type, card_metadata: {})
  end
end
