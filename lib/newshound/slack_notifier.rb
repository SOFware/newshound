# frozen_string_literal: true

require "slack-ruby-client"

module Newshound
  class SlackNotifier
    def initialize
      configure_slack_client
    end

    def post(message)
      return unless valid_configuration?
      
      if webhook_configured?
        post_via_webhook(message)
      elsif web_api_configured?
        post_via_web_api(message)
      else
        Rails.logger.error "Newshound: No valid Slack configuration found"
      end
    rescue StandardError => e
      Rails.logger.error "Newshound: Failed to send Slack notification: #{e.message}"
    end

    private

    def configure_slack_client
      Slack.configure do |config|
        config.token = ENV["SLACK_API_TOKEN"] if ENV["SLACK_API_TOKEN"]
      end
    end

    def valid_configuration?
      return false unless Newshound.configuration.valid?
      
      webhook_configured? || web_api_configured?
    end

    def webhook_configured?
      Newshound.configuration.slack_webhook_url.present?
    end

    def web_api_configured?
      ENV["SLACK_API_TOKEN"].present?
    end

    def post_via_webhook(message)
      client = Slack::Incoming::Webhook.new(Newshound.configuration.slack_webhook_url)
      client.post(message)
    end

    def post_via_web_api(message)
      client = Slack::Web::Client.new
      client.chat_postMessage(
        channel: Newshound.configuration.slack_channel,
        blocks: message[:blocks],
        text: "Daily Newshound Report"
      )
    end
  end
end