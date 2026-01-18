# frozen_string_literal: true

class Entity < ApplicationRecord
  # A named thing within a domain that can participate in facts.
  # Entities have types, aliases, and can be linked to external systems.
  #
  # Examples:
  #   - Person: "John Smith", "Sarah Chen"
  #   - System: "Payment Gateway", "Auth Service"
  #   - Concept: "OAuth 2.0", "REST API"
  #   - Artifact: "User Model", "LoginController"

  ENTITY_TYPES = %w[
    person
    system
    concept
    location
    organization
    artifact
    event
    metric
  ].freeze

  belongs_to :domain
  belongs_to :created_by, class_name: "User", optional: true
  has_many :subject_facts, class_name: "Fact", foreign_key: :subject_entity_id, dependent: :destroy
  has_many :object_facts, class_name: "Fact", foreign_key: :object_entity_id, dependent: :nullify
  has_many :entity_mentions, dependent: :destroy
  has_many :mentioned_in_cards, through: :entity_mentions, source: :card

  validates :name, presence: true, uniqueness: { scope: :domain_id }
  validates :name, length: { maximum: 200 }
  validates :entity_type, presence: true, inclusion: { in: ENTITY_TYPES }
  validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  scope :by_type, ->(type) { where(entity_type: type) }
  scope :high_confidence, -> { where("confidence >= ?", 0.8) }
  scope :ai_extracted, -> { where("confidence < ?", 1.0) }
  scope :user_created, -> { where(confidence: 1.0) }
  scope :with_external_link, -> { where.not(external_id: nil) }

  # Find entity by name or any alias
  scope :named, ->(name) {
    where(name: name).or(
      where("EXISTS (SELECT 1 FROM json_each(aliases) WHERE json_each.value = ?)", name)
    )
  }

  def add_alias(new_alias)
    return if new_alias.blank? || all_names.include?(new_alias)

    self.aliases = (aliases || []) + [new_alias]
    save
  end

  def all_names
    [name] + (aliases || [])
  end

  def all_facts
    Fact.where(subject_entity_id: id).or(Fact.where(object_entity_id: id))
  end

  def related_entities
    entity_ids = all_facts.pluck(:subject_entity_id, :object_entity_id).flatten.uniq - [id]
    Entity.where(id: entity_ids)
  end

  def merge_into(target_entity)
    return false if target_entity.id == id
    return false if target_entity.domain_id != domain_id

    transaction do
      # Transfer aliases
      (all_names - target_entity.all_names).each do |alias_name|
        target_entity.add_alias(alias_name) unless alias_name == target_entity.name
      end

      # Update facts to point to target
      subject_facts.update_all(subject_entity_id: target_entity.id)
      object_facts.update_all(object_entity_id: target_entity.id)

      # Update mentions
      entity_mentions.update_all(entity_id: target_entity.id)

      destroy!
    end

    true
  end

  def ai_extracted?
    confidence < 1.0
  end

  def needs_review?
    ai_extracted? && confidence < 0.8
  end

  # Icon mapping for UI
  def icon
    case entity_type
    when "person" then "user"
    when "system" then "server"
    when "concept" then "lightbulb"
    when "location" then "map-pin"
    when "organization" then "building"
    when "artifact" then "file-code"
    when "event" then "calendar"
    when "metric" then "chart-bar"
    else "circle"
    end
  end
end
