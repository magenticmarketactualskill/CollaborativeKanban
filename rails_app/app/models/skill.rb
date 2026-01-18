class Skill < ApplicationRecord
  CATEGORIES = %w[analysis generation workflow transformation extraction].freeze
  SOURCES = %w[imported created system].freeze

  belongs_to :user, optional: true

  validates :name, presence: true
  validates :slug, presence: true, format: { with: /\A[a-z0-9\-_]+\z/, message: "must be lowercase alphanumeric with dashes or underscores" }
  validates :prompt_template, presence: true
  validates :category, inclusion: { in: CATEGORIES }, allow_blank: true
  validates :source, inclusion: { in: SOURCES }, allow_blank: true
  validates :slug, uniqueness: { scope: :user_id }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :enabled, -> { where(enabled: true) }
  scope :system_skills, -> { where(system_skill: true) }
  scope :user_skills, -> { where(system_skill: false) }
  scope :for_user, ->(user) { where(user_id: [ nil, user&.id ]) }
  scope :by_category, ->(cat) { where(category: cat) }

  def execute(params = {}, llm_config: nil)
    LlmClient::Skills::Executor.new(to_skill_definition, params, user: user).call
  end

  def to_markdown
    LlmClient::Skills::Exporter.new(self).to_markdown
  end

  def self.from_markdown(content, user: nil, filename: nil)
    definition = LlmClient::Skills::Importer.new(content, filename: filename).import
    Skill.new(
      user: user,
      **definition.to_h.slice(
        :name, :slug, :version, :description, :category,
        :parameters, :prompt_template, :workflow_steps,
        :dependencies, :metadata
      ),
      source: "imported",
      source_file: filename
    )
  end

  def self.from_markdown!(content, user: nil, filename: nil)
    skill = from_markdown(content, user: user, filename: filename)
    skill.save!
    skill
  end

  # Convert to gem's SkillDefinition PORO
  def to_skill_definition
    LlmClient::Skills::SkillDefinition.from_record(self)
  end

  def parameter_names
    parameters.map { |p| p["name"] }
  end

  def required_parameters
    parameters.select { |p| p["required"] }
  end

  def has_workflow?
    workflow_steps.present? && workflow_steps.any?
  end

  private

  def generate_slug
    self.slug = name.parameterize
  end
end
