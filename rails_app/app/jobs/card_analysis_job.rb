# frozen_string_literal: true

class CardAnalysisJob < ApplicationJob
  queue_as :low_priority
  retry_on Llm::BaseClient::RateLimitError, wait: 30.seconds, attempts: 3

  def perform(card_id)
    card = Card.find_by(id: card_id)
    return unless card

    analyzer = CardIntelligence::ContentAnalyzer.new
    result = analyzer.analyze(card)

    if result.success?
      card.update!(
        ai_summary: result.summary,
        ai_analyzed_at: Time.current
      )

      # Store detailed analysis in metadata
      card.update_column(:card_metadata, card.card_metadata.merge(
        "ai_analysis" => result.to_h,
        "ai_analysis_provider" => result.provider.to_s
      ))

      # Broadcast update
      broadcast_card_analysis(card, result)
    end
  end

  private

  def broadcast_card_analysis(card, result)
    Turbo::StreamsChannel.broadcast_update_to(
      "card_#{card.id}",
      target: "card-#{card.id}-analysis",
      partial: "cards/analysis",
      locals: { card: card, analysis: result }
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to broadcast analysis update: #{e.message}")
  end
end
