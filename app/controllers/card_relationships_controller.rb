# frozen_string_literal: true

class CardRelationshipsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_board
  before_action :set_card
  before_action :require_board_access!
  before_action :require_board_edit_access!, except: [:index]
  before_action :set_relationship, only: [:destroy]

  def index
    @relationships = {
      blocks: @card.blocks,
      blocked_by: @card.blocked_by,
      depends_on: @card.depends_on,
      dependencies: @card.dependencies,
      related: @card.related_cards
    }

    respond_to do |format|
      format.html
      format.json { render json: @relationships }
    end
  end

  def create
    @relationship = CardRelationship.new(relationship_params)
    @relationship.source_card = @card
    @relationship.created_by = current_user

    if @relationship.save
      respond_to do |format|
        format.html { redirect_to board_card_path(@board, @card), notice: 'Relationship created.' }
        format.turbo_stream
        format.json { render json: @relationship, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to board_card_path(@board, @card), alert: @relationship.errors.full_messages.join(', ') }
        format.json { render json: { errors: @relationship.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @relationship.destroy

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Relationship removed.' }
      format.turbo_stream
      format.json { head :no_content }
    end
  end

  def detect
    RelationshipDetectionJob.perform_later(@card.id)

    respond_to do |format|
      format.html { redirect_to board_card_path(@board, @card), notice: 'Analyzing relationships...' }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "card-#{@card.id}-relationship-suggestions",
          partial: "cards/relationship_suggestions_loading",
          locals: { card: @card, stage: 0 }
        )
      end
      format.json { render json: { status: 'analyzing' } }
    end
  end

  private

  def set_board
    @board = Board.find(params[:board_id])
  end

  def set_card
    @card = @board.cards.find(params[:card_id])
  end

  def set_relationship
    @relationship = @card.outgoing_relationships.find(params[:id])
  end

  def relationship_params
    params.require(:card_relationship).permit(:target_card_id, :relationship_type)
  end
end
