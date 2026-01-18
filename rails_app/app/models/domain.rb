# frozen_string_literal: true

class Domain < EntityKnowledge::Domain
  # App-specific association to board
  belongs_to :board

  # Override uniqueness validation to include board scope
  validates :name, uniqueness: { scope: :board_id }

  def self.create_from_template(board:, template_name:)
    template = TEMPLATES[template_name]
    return [] unless template

    template.map do |attrs|
      board.domains.create!(attrs.merge(system_generated: true))
    end
  end
end
