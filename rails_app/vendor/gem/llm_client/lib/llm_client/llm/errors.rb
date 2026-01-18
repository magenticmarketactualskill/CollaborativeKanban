# frozen_string_literal: true

module LlmClient
  module Llm
    class Error < LlmClient::Error; end
    class ConnectionError < Error; end
    class TimeoutError < Error; end
    class RateLimitError < Error; end
    class InvalidResponseError < Error; end

    class ValidationError < Error
      attr_reader :errors

      def initialize(errors)
        @errors = errors
        super("Schema validation failed: #{errors.map { |e| e['error'] }.join(', ')}")
      end
    end
  end
end
