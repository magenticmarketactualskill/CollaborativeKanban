# frozen_string_literal: true

module EntityKnowledge
  class Domain < ApplicationRecord
    # A bounded context for organizing entities and facts.
    # Domains can be hierarchical and scoped to a parent object.
    #
    # Examples:
    #   - "Authentication" domain containing User, Session, Token entities
    #   - "Payment" domain containing Order, Transaction, Refund entities
    #   - "Infrastructure" domain with Server, Database, Cache entities

    self.table_name = "domains"

    # Standard domain colors for UI
    DOMAIN_COLORS = {
      "technical" => "#3B82F6",
      "business" => "#10B981",
      "people" => "#F59E0B",
      "process" => "#8B5CF6",
      "infrastructure" => "#6B7280"
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

    # Hierarchy
    belongs_to :parent_domain, class_name: "EntityKnowledge::Domain", optional: true
    has_many :child_domains, class_name: "EntityKnowledge::Domain", foreign_key: :parent_domain_id, dependent: :nullify

    # Knowledge graph
    has_many :entities, class_name: "EntityKnowledge::Entity", dependent: :destroy
    has_many :facts, class_name: "EntityKnowledge::Fact", dependent: :destroy

    validates :name, presence: true, length: { maximum: 100 }
    validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, allow_blank: true }

    scope :root_domains, -> { where(parent_domain_id: nil) }
    scope :system_generated, -> { where(system_generated: true) }
    scope :user_created, -> { where(system_generated: false) }

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
end
