# frozen_string_literal: true

class CardTypeInferenceJob < ApplicationJob
  queue_as :default
  retry_on Llm::BaseClient::ConnectionError, wait: :polynomially_longer, attempts: 3

  def perform(card_id)
    card = Card.find_by(id: card_id)
    return unless card

    # Skip if already inferred with high confidence
    return if card.type_inference_confidence == "high"

    inferrer = CardIntelligence::TypeInferrer.new
    result = inferrer.infer(title: card.title, description: card.description)

    card.update!(
      card_type: result.type,
      type_inference_confidence: result.confidence.to_s,
      type_inferred_at: Time.current
    )

    # Broadcast update via Turbo Streams
    broadcast_card_update(card)
  end

  private

  def broadcast_card_update(card)
    Turbo::StreamsChannel.broadcast_replace_to(
      "board_#{card.board_id}",
      target: "card-#{card.id}",
      partial: "boards/card",
      locals: { card: card, board: card.board }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to broadcast card update: #{e.message}")
  end
end
