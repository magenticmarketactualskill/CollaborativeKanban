module LlmSelectable
  extend ActiveSupport::Concern

  included do
    class_attribute :llm_task_mappings, default: {}
  end

  class_methods do
    def llm_task(task_name, provider_types: nil, fallback_types: nil, timeout: 30)
      llm_task_mappings[task_name] = {
        provider_types: Array(provider_types),
        fallback_types: Array(fallback_types),
        timeout: timeout
      }
    end
  end

  def select_llm_for(task_name, user: nil)
    mapping = self.class.llm_task_mappings[task_name]
    return nil unless mapping

    config = find_llm_config(
      provider_types: mapping[:provider_types],
      fallback_types: mapping[:fallback_types],
      user: user
    )

    return nil unless config

    LlmSelection.new(
      configuration: config,
      timeout: mapping[:timeout]
    )
  end

  def with_llm(task_name, user: nil)
    selection = select_llm_for(task_name, user: user)
    return yield(nil) unless selection

    yield(selection)
  end

  private

  def find_llm_config(provider_types:, fallback_types:, user:)
    config = try_provider_types(provider_types, user)
    config ||= try_provider_types(fallback_types, user) if fallback_types.present?
    config
  end

  def try_provider_types(provider_types, user)
    return nil if provider_types.blank?

    LlmConfiguration.find_available(
      provider_types: provider_types,
      user: user
    )
  end

  class LlmSelection
    attr_reader :configuration, :timeout

    def initialize(configuration:, timeout:)
      @configuration = configuration
      @timeout = timeout
    end

    def provider
      configuration.provider
    end

    def generate(prompt, **options)
      merged_options = options.merge(timeout: timeout)
      configuration.generate(prompt, **merged_options)
    end

    def model
      configuration.model
    end

    def provider_type
      configuration.provider_type
    end

    delegate :available?, :test_connection, to: :configuration
  end
end
