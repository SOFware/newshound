# frozen_string_literal: true

module Newshound
  class Configuration
    attr_accessor :slack_webhook_url, :slack_channel, :report_time,
                  :exception_limit, :time_zone, :enabled

    def initialize
      @slack_webhook_url = nil
      @slack_channel = "#general"
      @report_time = "09:00"
      @exception_limit = 4
      @time_zone = "America/New_York"
      @enabled = true
    end

    def valid?
      return false unless enabled
      return false if slack_webhook_url.nil? || slack_webhook_url.empty?
      
      true
    end
  end
end