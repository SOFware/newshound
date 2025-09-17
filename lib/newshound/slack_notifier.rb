# frozen_string_literal: true

require "slack-ruby-client"

module Newshound
  class SlackNotifier
    attr_reader :configuration, :logger, :webhook_client, :web_api_client

    def initialize(configuration: nil, logger: nil, webhook_client: nil, web_api_client: nil)
      @configuration = configuration || Newshound.configuration
      @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new(STDOUT))
      @webhook_client = webhook_client
      @web_api_client = web_api_client
      configure_slack_client
    end

    def post(message)
      return unless configuration.valid?

      if webhook_configured?
        post_via_webhook(message)
      elsif web_api_configured?
        post_via_web_api(message)
      else
        logger.error "Newshound: No valid Slack configuration found"
      end
    rescue StandardError => e
      logger.error "Newshound: Failed to send Slack notification: #{e.message}"
    end

    private

    def configure_slack_client
      Slack.configure do |config|
        config.token = ENV["SLACK_API_TOKEN"] if ENV["SLACK_API_TOKEN"]
      end
    end

    def webhook_configured?
      !configuration.slack_webhook_url.nil? && !configuration.slack_webhook_url.empty?
    end

    def web_api_configured?
      !ENV["SLACK_API_TOKEN"].nil? && !ENV["SLACK_API_TOKEN"].empty?
    end

    def post_via_webhook(message)
      client = webhook_client || Slack::Incoming::Webhook.new(configuration.slack_webhook_url)
      client.post(message)
    end

    def post_via_web_api(message)
      client = web_api_client || Slack::Web::Client.new
      client.chat_postMessage(
        channel: configuration.slack_channel,
        blocks: message[:blocks],
        text: "Daily Newshound Report"
      )
    end
  end
end