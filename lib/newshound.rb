# frozen_string_literal: true

require_relative "newshound/version"
require_relative "newshound/configuration"
require_relative "newshound/exception_reporter"
require_relative "newshound/que_reporter"
require_relative "newshound/slack_notifier"
require_relative "newshound/daily_report_job"
require_relative "newshound/scheduler"
require_relative "newshound/railtie" if defined?(Rails)

module Newshound
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def report!
      slack_notifier = SlackNotifier.new
      
      exception_report = ExceptionReporter.new.generate_report
      que_report = QueReporter.new.generate_report
      
      message = format_daily_report(exception_report, que_report)
      slack_notifier.post(message)
    end

    private

    def format_daily_report(exception_report, que_report)
      {
        blocks: [
          {
            type: "header",
            text: {
              type: "plain_text",
              text: "🐕 Daily Newshound Report",
              emoji: true
            }
          },
          {
            type: "section",
            text: {
              type: "mrkdwn",
              text: "*Date:* #{Date.current.strftime('%B %d, %Y')}"
            }
          },
          {
            type: "divider"
          },
          *exception_report,
          {
            type: "divider"
          },
          *que_report
        ]
      }
    end
  end
end