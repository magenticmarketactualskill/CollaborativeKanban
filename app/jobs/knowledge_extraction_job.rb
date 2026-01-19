# frozen_string_literal: true

class KnowledgeExtractionJob < ApplicationJob
  queue_as :default

  def perform(card_id)
    task = KnowledgeExtractionTask.new(card_id: card_id)
    task.run

    if task.success?
      result = task.results.last&.value!
      Rails.logger.info(
        "[KnowledgeExtraction] Card #{card_id} completed: " \
        "#{result[:counts][:entities]} entities, " \
        "#{result[:counts][:facts]} facts, " \
        "#{result[:counts][:mentions]} mentions"
      )
    else
      failure = task.results.find(&:failure?)&.failure
      Rails.logger.error("[KnowledgeExtraction] Card #{card_id} failed: #{failure}")
    end
  end
end
