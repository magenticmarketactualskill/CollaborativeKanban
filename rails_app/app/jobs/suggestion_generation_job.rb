# frozen_string_literal: true

class SuggestionGenerationJob < ApplicationJob
  queue_as :low_priority
  retry_on Llm::BaseClient::RateLimitError, wait: 30.seconds, attempts: 3

  def perform(card_id)
    task = SuggestionGenerationTask.new(card_id: card_id)
    result = task.run { |r| r.value! }

    if result.failure?
      Rails.logger.error("SuggestionGenerationTask failed: #{result.failure[:error]}")
    end
  end
end
