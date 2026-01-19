# frozen_string_literal: true

class CardTypeInferenceJob < ApplicationJob
  queue_as :default
  retry_on Llm::BaseClient::ConnectionError, wait: :polynomially_longer, attempts: 3

  def perform(card_id)
    task = TypeInferenceTask.new(card_id: card_id)
    result = task.run_conditional { |r| r.value! }

    if result.failure?
      failure = result.failure
      # Don't re-raise for expected skips (already high confidence)
      unless failure[:skipped]
        Rails.logger.error("TypeInferenceTask failed: #{failure[:error]}")
      end
    end
  end
end
