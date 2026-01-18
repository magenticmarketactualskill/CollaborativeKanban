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
    Skills::Executor.new(self, params, llm_config: llm_config).call
  end

  def to_markdown
    Skills::Exporter.new(self).to_markdown
  end

  def self.from_markdown(content, user: nil, filename: nil)
    Skills::Importer.new(content, user: user, filename: filename).import
  end

  def self.from_markdown!(content, user: nil, filename: nil)
    Skills::Importer.new(content, user: user, filename: filename).import!
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
