# frozen_string_literal: true

module LlmClient
  module Mcp
    class Error < LlmClient::Error; end
    class ConnectionError < Error; end
    class NotConnectedError < Error; end
    class TimeoutError < Error; end
    class ToolNotFoundError < Error; end

    class RpcError < Error
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end
  end
end
