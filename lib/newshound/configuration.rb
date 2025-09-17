# frozen_string_literal: true

module Newshound
  class Configuration
    attr_accessor :slack_webhook_url, :slack_channel, :report_time,
                  :exception_limit, :time_zone, :enabled,
                  :transport_adapter, :sns_topic_arn, :aws_region,
                  :aws_access_key_id, :aws_secret_access_key

    def initialize
      @slack_webhook_url = nil
      @slack_channel = "#general"
      @report_time = "09:00"
      @exception_limit = 4
      @time_zone = "America/New_York"
      @enabled = true
      @transport_adapter = :slack
      @sns_topic_arn = nil
      @aws_region = nil
      @aws_access_key_id = nil
      @aws_secret_access_key = nil
    end

    def valid?
      return false unless enabled
      return false if slack_webhook_url.nil? || slack_webhook_url.empty?
      
      true
    end
  end
end