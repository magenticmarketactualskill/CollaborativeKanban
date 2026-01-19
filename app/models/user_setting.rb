class UserSetting < ApplicationRecord
  PROVIDERS = %w[local remote].freeze
  REMOTE_PROVIDERS = %w[openai anthropic openrouter custom].freeze

  belongs_to :user

  validates :active_provider, presence: true, inclusion: { in: PROVIDERS }
  validates :remote_provider, inclusion: { in: REMOTE_PROVIDERS }, allow_blank: true

  def test_connection
    if active_provider == 'local'
      test_local_connection
    else
      test_remote_connection
    end
  end

  def llm_config
    if active_provider == 'local'
      {
        endpoint: local_endpoint,
        model: local_model,
        api_key: local_api_key.presence
      }
    else
      {
        provider: remote_provider,
        endpoint: effective_remote_endpoint,
        model: remote_model,
        api_key: remote_api_key
      }
    end
  end

  def effective_remote_endpoint
    case remote_provider
    when 'openai'
      'https://api.openai.com/v1'
    when 'anthropic'
      'https://api.anthropic.com/v1'
    when 'openrouter'
      'https://openrouter.ai/api/v1'
    when 'custom'
      remote_endpoint
    else
      remote_endpoint
    end
  end

  private

  def test_local_connection
    require 'net/http'
    require 'uri'
    require 'json'

    begin
      uri = URI.parse("#{local_endpoint}/models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 5
      http.read_timeout = 5

      request = Net::HTTP::Get.new(uri.path)
      request['Authorization'] = "Bearer #{local_api_key}" if local_api_key.present?

      response = http.request(request)

      if response.code.to_i == 200
        { success: true, message: "Connected to local LLM at #{local_endpoint}" }
      else
        { success: false, message: "Failed to connect: HTTP #{response.code}" }
      end
    rescue Errno::ECONNREFUSED
      { success: false, message: "Connection refused. Is the local LLM server running?" }
    rescue Net::OpenTimeout, Net::ReadTimeout
      { success: false, message: "Connection timed out. Check the endpoint URL." }
    rescue StandardError => e
      { success: false, message: "Error: #{e.message}" }
    end
  end

  def test_remote_connection
    require 'net/http'
    require 'uri'
    require 'json'

    return { success: false, message: "API key is required for remote providers" } if remote_api_key.blank?

    begin
      endpoint = effective_remote_endpoint

      if remote_provider == 'anthropic'
        # Anthropic has a different API structure
        uri = URI.parse("#{endpoint}/messages")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request['x-api-key'] = remote_api_key
        request['anthropic-version'] = '2023-06-01'
        request.body = {
          model: remote_model,
          max_tokens: 10,
          messages: [{ role: 'user', content: 'Hi' }]
        }.to_json

        response = http.request(request)

        if response.code.to_i == 200
          { success: true, message: "Connected to Anthropic API" }
        elsif response.code.to_i == 401
          { success: false, message: "Invalid API key" }
        else
          { success: false, message: "Failed to connect: HTTP #{response.code}" }
        end
      else
        # OpenAI-compatible API
        uri = URI.parse("#{endpoint}/models")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 10
        http.read_timeout = 10

        request = Net::HTTP::Get.new(uri.path)
        request['Authorization'] = "Bearer #{remote_api_key}"

        response = http.request(request)

        if response.code.to_i == 200
          { success: true, message: "Connected to #{remote_provider.titleize} API" }
        elsif response.code.to_i == 401
          { success: false, message: "Invalid API key" }
        else
          { success: false, message: "Failed to connect: HTTP #{response.code}" }
        end
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      { success: false, message: "Connection timed out" }
    rescue StandardError => e
      { success: false, message: "Error: #{e.message}" }
    end
  end
end
