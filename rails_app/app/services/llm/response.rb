# frozen_string_literal: true

module Llm
  class Response
    attr_reader :content, :model, :provider, :latency, :error

    def initialize(content:, provider:, model: nil, latency: nil, error: nil, success: true)
      @content = content
      @model = model
      @provider = provider
      @latency = latency
      @error = error
      @success = success
    end

    def success?
      @success && content.present?
    end

    def failure?
      !success?
    end

    def to_h
      {
        content: content,
        model: model,
        provider: provider,
        latency: latency,
        error: error,
        success: success?
      }
    end

    # Parse JSON content safely
    def parsed_json
      return nil unless success?

      JSON.parse(content)
    rescue JSON::ParserError
      nil
    end

    # Extract content between markers
    def extract(start_marker, end_marker = nil)
      return nil unless success?

      if end_marker
        match = content.match(/#{Regexp.escape(start_marker)}(.+?)#{Regexp.escape(end_marker)}/m)
        match&.[](1)&.strip
      else
        content.split(start_marker).last&.strip
      end
    end
  end
end
