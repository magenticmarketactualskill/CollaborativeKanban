# frozen_string_literal: true

module LlmClient
  module Skills
    class Error < LlmClient::Error; end
    class MissingParameterError < Error; end
    class InvalidWorkflowError < Error; end
    class ExecutionError < Error; end
    class InvalidFormatError < Error; end
  end
end
