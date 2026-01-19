module LlmConfig
  class Setup
    DEFAULT_CONFIGURATIONS = [
      {
        name: "Ollama Local",
        provider_type: "ollama",
        model: "llama3.2:3b",
        endpoint: "http://localhost:11434",
        default_for_type: true,
        priority: 10,
        options: { temperature: 0.7 }
      },
      {
        name: "Claude Haiku",
        provider_type: "anthropic",
        model: "claude-3-5-haiku-20241022",
        default_for_type: true,
        priority: 5,
        options: { max_tokens: 4096 }
      },
      {
        name: "Claude Sonnet",
        provider_type: "anthropic",
        model: "claude-3-5-sonnet-20241022",
        priority: 10,
        options: { max_tokens: 8192 }
      },
      {
        name: "GPT-4o Mini",
        provider_type: "openai",
        model: "gpt-4o-mini",
        default_for_type: true,
        priority: 5,
        options: { temperature: 0.7 }
      },
      {
        name: "GPT-4o",
        provider_type: "openai",
        model: "gpt-4o",
        priority: 10,
        options: { temperature: 0.7 }
      }
    ].freeze

    class << self
      def call(reset: false)
        new.call(reset: reset)
      end

      def configure(&block)
        instance = new
        instance.instance_eval(&block)
        instance
      end
    end

    attr_reader :configurations

    def initialize
      @configurations = []
    end

    def call(reset: false)
      if reset
        LlmConfiguration.destroy_all
        Rails.logger.info "[LlmConfig::Setup] Reset all configurations"
      end

      seed_defaults
      apply_environment_overrides
      log_summary

      self
    end

    def add(name:, provider_type:, model:, **options)
      @configurations << {
        name: name,
        provider_type: provider_type,
        model: model,
        **options
      }
      self
    end

    def ollama(name:, model:, endpoint: nil, **options)
      add(
        name: name,
        provider_type: "ollama",
        model: model,
        endpoint: endpoint || "http://localhost:11434",
        **options
      )
    end

    def anthropic(name:, model:, api_key: nil, **options)
      add(
        name: name,
        provider_type: "anthropic",
        model: model,
        api_key: api_key,
        **options
      )
    end

    def openai(name:, model:, api_key: nil, **options)
      add(
        name: name,
        provider_type: "openai",
        model: model,
        api_key: api_key,
        **options
      )
    end

    def openrouter(name:, model:, api_key: nil, **options)
      add(
        name: name,
        provider_type: "openrouter",
        model: model,
        api_key: api_key,
        **options
      )
    end

    def custom(name:, model:, endpoint:, **options)
      add(
        name: name,
        provider_type: "custom",
        model: model,
        endpoint: endpoint,
        **options
      )
    end

    def apply!
      @configurations.each do |config|
        find_or_create_configuration(config)
      end
      log_summary
      self
    end

    private

    def seed_defaults
      DEFAULT_CONFIGURATIONS.each do |config|
        find_or_create_configuration(config)
      end
    end

    def find_or_create_configuration(attrs)
      name = attrs[:name]
      existing = LlmConfiguration.find_by(name: name, user_id: nil)

      if existing
        Rails.logger.debug "[LlmConfig::Setup] Configuration '#{name}' already exists"
        existing
      else
        config = LlmConfiguration.create!(attrs.merge(user_id: nil))
        Rails.logger.info "[LlmConfig::Setup] Created configuration '#{name}'"
        config
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[LlmConfig::Setup] Failed to create '#{name}': #{e.message}"
      nil
    end

    def apply_environment_overrides
      apply_ollama_env_override
      apply_anthropic_env_override
      apply_openai_env_override
    end

    def apply_ollama_env_override
      return unless ENV["OLLAMA_HOST"].present? || ENV["OLLAMA_MODEL"].present?

      config = LlmConfiguration.find_by(name: "Ollama Local", user_id: nil)
      return unless config

      updates = {}
      updates[:endpoint] = ENV["OLLAMA_HOST"] if ENV["OLLAMA_HOST"].present?
      updates[:model] = ENV["OLLAMA_MODEL"] if ENV["OLLAMA_MODEL"].present?

      config.update!(updates) if updates.present?
      Rails.logger.info "[LlmConfig::Setup] Applied Ollama environment overrides"
    end

    def apply_anthropic_env_override
      return unless ENV["ANTHROPIC_API_KEY"].present?

      LlmConfiguration.where(provider_type: "anthropic", user_id: nil).find_each do |config|
        config.update!(api_key: ENV["ANTHROPIC_API_KEY"])
      end
      Rails.logger.info "[LlmConfig::Setup] Applied Anthropic API key from environment"
    end

    def apply_openai_env_override
      return unless ENV["OPENAI_API_KEY"].present?

      LlmConfiguration.where(provider_type: "openai", user_id: nil).find_each do |config|
        config.update!(api_key: ENV["OPENAI_API_KEY"])
      end
      Rails.logger.info "[LlmConfig::Setup] Applied OpenAI API key from environment"
    end

    def log_summary
      counts = LlmConfiguration.group(:provider_type).count
      Rails.logger.info "[LlmConfig::Setup] Configuration summary: #{counts.map { |k, v| "#{k}=#{v}" }.join(', ')}"
    end
  end
end
