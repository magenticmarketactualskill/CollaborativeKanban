# frozen_string_literal: true

module LlmClient
  # Base error class for all LlmClient errors
  class Error < StandardError; end

  # Configuration errors
  class ConfigurationError < Error; end

  # Raised when a required callback is not configured
  class CallbackNotConfiguredError < ConfigurationError
    def initialize(callback_name)
      super("Required callback '#{callback_name}' is not configured. Set it via LlmClient.configure")
    end
  end
end
