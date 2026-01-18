# frozen_string_literal: true

class Domain < ApplicationRecord
  # A bounded context for organizing entities and facts.
  # Domains are scoped to boards and can be hierarchical.
  #
  # Examples:
  #   - "Authentication" domain containing User, Session, Token entities
  #   - "Payment" domain containing Order, Transaction, Refund entities
  #   - "Infrastructure" domain with Server, Database, Cache entities

  belongs_to :board
  belongs_to :parent_domain, class_name: "Domain", optional: true
  has_many :child_domains, class_name: "Domain", foreign_key: :parent_domain_id, dependent: :nullify
  has_many :entities, dependent: :destroy
  has_many :facts, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :board_id }
  validates :name, length: { maximum: 100 }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }

  scope :root_domains, -> { where(parent_domain_id: nil) }
  scope :system_generated, -> { where(system_generated: true) }
  scope :user_created, -> { where(system_generated: false) }

  # Standard domain colors for UI
  DOMAIN_COLORS = {
    "technical" => "#3B82F6",   # blue
    "business" => "#10B981",    # green
    "people" => "#F59E0B",      # amber
    "process" => "#8B5CF6",     # purple
    "infrastructure" => "#6B7280" # gray
  }.freeze

  # Predefined domain templates for quick setup
  TEMPLATES = {
    "software_project" => [
      { name: "Architecture", description: "System components and design patterns", color: "#3B82F6" },
      { name: "Features", description: "Product features and requirements", color: "#10B981" },
      { name: "Team", description: "People and roles", color: "#F59E0B" },
      { name: "Infrastructure", description: "Servers, databases, and services", color: "#6B7280" }
    ],
    "product_development" => [
      { name: "Users", description: "User segments and personas", color: "#F59E0B" },
      { name: "Features", description: "Product capabilities", color: "#10B981" },
      { name: "Metrics", description: "KPIs and measurements", color: "#8B5CF6" },
      { name: "Competitors", description: "Market landscape", color: "#EF4444" }
    ]
  }.freeze

  def self.create_from_template(board:, template_name:)
    template = TEMPLATES[template_name]
    return [] unless template

    template.map do |attrs|
      board.domains.create!(attrs.merge(system_generated: true))
    end
  end

  def full_path
    ancestors.reverse.push(self).map(&:name).join(" > ")
  end

  def ancestors
    return [] unless parent_domain

    [parent_domain] + parent_domain.ancestors
  end

  def descendants
    child_domains.flat_map { |child| [child] + child.descendants }
  end

  def entity_count
    entities.count + descendants.sum(&:entity_count)
  end

  def fact_count
    facts.count + descendants.sum(&:fact_count)
  end
end
