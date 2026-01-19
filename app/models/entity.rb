# frozen_string_literal: true

class Entity < EntityKnowledge::Entity
  # App-specific associations
  belongs_to :created_by, class_name: "User", optional: true
  has_many :entity_mentions, dependent: :destroy
  has_many :mentioned_in_cards, through: :entity_mentions, source: :card

  # Override uniqueness validation to include domain scope
  validates :name, uniqueness: { scope: :domain_id }

  # Override to use app-level Fact model
  def all_facts
    Fact.where(subject_entity_id: id).or(Fact.where(object_entity_id: id))
  end

  # Override merge to also handle app-specific mentions
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

      # Update mentions (app-specific)
      entity_mentions.update_all(entity_id: target_entity.id)

      destroy!
    end

    true
  end
end
