class LlmConfiguration < ApplicationRecord
  PROVIDER_TYPES = %w[openai anthropic ollama openrouter custom].freeze

  belongs_to :user, optional: true
  has_many :llm_calls, dependent: :destroy
  has_many :llm_stages, through: :llm_calls

  validates :name, presence: true
  validates :provider_type, presence: true, inclusion: { in: PROVIDER_TYPES }
  validates :model, presence: true
  validates :name, uniqueness: { scope: :user_id }

  scope :active, -> { where(active: true) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :for_provider, ->(type) { where(provider_type: type) }
  scope :defaults, -> { where(default_for_type: true) }
  scope :global, -> { where(user_id: nil) }
  scope :for_user, ->(user) { where(user_id: [nil, user&.id]) }

  before_save :ensure_single_default, if: :default_for_type_changed?

  def provider
    @provider ||= LlmClient::Providers.for(self)
  end

  def test_connection
    provider.test_connection
  end

  def generate(prompt, **options)
    provider.generate(prompt, **options)
  end

  def available?
    provider.available?
  end

  def effective_endpoint
    endpoint.presence || provider.class.default_endpoint
  end

  def self.default_for(provider_type)
    for_provider(provider_type).defaults.first || for_provider(provider_type).active.by_priority.first
  end

  def self.find_available(provider_types: nil, user: nil)
    scope = active.by_priority
    scope = scope.for_user(user) if user
    scope = scope.for_provider(provider_types) if provider_types.present?
    scope.find(&:available?)
  end

  private

  def ensure_single_default
    return unless default_for_type

    LlmConfiguration
      .where(provider_type: provider_type, default_for_type: true)
      .where.not(id: id)
      .update_all(default_for_type: false)
  end
end
