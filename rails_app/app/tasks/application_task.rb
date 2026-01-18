# frozen_string_literal: true

class ApplicationTask < TaskFrame::Task
  include Dry::Monads[:result, :do]

  attr_reader :card_id, :card

  def initialize(card_id:)
    super()
    @card_id = card_id
    @card = nil
  end

  # Access previous stage results by stage class
  def result_for(stage_klass)
    index = stage_klass_sequence.index(stage_klass)
    return nil unless index && results[index]

    results[index].value! if results[index].success?
  end

  # Broadcast a turbo stream replacement
  def broadcast_replace(stream:, target:, partial:, locals: {})
    Turbo::StreamsChannel.broadcast_replace_to(
      stream,
      target: target,
      partial: partial,
      locals: locals
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to broadcast: #{e.message}")
  end

  # Broadcast a turbo stream update
  def broadcast_update(stream:, target:, partial:, locals: {})
    Turbo::StreamsChannel.broadcast_update_to(
      stream,
      target: target,
      partial: partial,
      locals: locals
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to broadcast: #{e.message}")
  end
end
