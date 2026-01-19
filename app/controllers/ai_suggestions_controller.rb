# frozen_string_literal: true

class AiSuggestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board
  before_action :set_card
  before_action :require_board_access!
  before_action :require_board_edit_access!
  before_action :set_suggestion

  def accept
    @suggestion.accept!

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Suggestion accepted.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@suggestion)
      end
      format.json { render json: { status: 'accepted' } }
    end
  end

  def dismiss
    @suggestion.dismiss!

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Suggestion dismissed.' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@suggestion)
      end
      format.json { render json: { status: 'dismissed' } }
    end
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_card
    @card = @board.cards.find(params[:card_id])
  end

  def set_suggestion
    @suggestion = @card.ai_suggestions.find(params[:id])
  end
end
