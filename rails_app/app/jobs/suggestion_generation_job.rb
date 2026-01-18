# frozen_string_literal: true

class SuggestionGenerationJob < ApplicationJob
  queue_as :low_priority
  retry_on Llm::BaseClient::RateLimitError, wait: 30.seconds, attempts: 3

  def perform(card_id)
    card = Card.find_by(id: card_id)
    return unless card

    generator = CardIntelligence::SuggestionGenerator.new
    suggestions = generator.generate(card)

    # Clear old pending suggestions
    card.ai_suggestions.pending.destroy_all

    # Save new suggestions
    saved_suggestions = suggestions.select(&:save)

    # Broadcast if there are new suggestions
    if saved_suggestions.any?
      broadcast_suggestions(card, saved_suggestions)
    end
  end

  private

  def broadcast_suggestions(card, suggestions)
    Turbo::StreamsChannel.broadcast_replace_to(
      "card_#{card.id}_suggestions",
      target: "card-#{card.id}-suggestions",
      partial: "cards/suggestions",
      locals: { card: card, suggestions: suggestions }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to broadcast suggestions: #{e.message}")
  end
end
