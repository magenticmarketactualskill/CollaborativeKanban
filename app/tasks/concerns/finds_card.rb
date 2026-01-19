# frozen_string_literal: true

module FindsCard
  extend ActiveSupport::Concern

  included do
    include Dry::Monads[:result]
  end

  def find_card
    card = Card.find_by(id: task.card_id)
    if card
      task.instance_variable_set(:@card, card)
      Success(card: card)
    else
      Failure(error: "Card not found", card_id: task.card_id, stage: name)
    end
  end
end
