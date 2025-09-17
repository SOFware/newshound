# frozen_string_literal: true

module Newshound
  class ExceptionReporter
    attr_reader :exception_source, :configuration, :time_range

    def initialize(exception_source: nil, configuration: nil, time_range: 24.hours)
      @exception_source = exception_source || (defined?(ExceptionTrack::Log) ? ExceptionTrack::Log : nil)
      @configuration = configuration || Newshound.configuration
      @time_range = time_range
    end

    def generate_report
      return no_exceptions_block if recent_exceptions.empty?

      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*🚨 Recent Exceptions (Last 24 Hours)*"
          }
        },
        *format_exceptions
      ]
    end

    private

    def recent_exceptions
      @recent_exceptions ||= fetch_recent_exceptions
    end

    def fetch_recent_exceptions
      return [] unless exception_source

      exception_source
        .where("created_at >= ?", time_range.ago)
        .order(created_at: :desc)
        .limit(configuration.exception_limit)
    end

    def format_exceptions
      recent_exceptions.map.with_index do |exception, index|
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: format_exception_text(exception, index + 1)
          }
        }
      end
    end

    def format_exception_text(exception, number)
      <<~TEXT
        *#{number}. #{exception.title || exception.exception_class}*
        • *Time:* #{exception.created_at.strftime('%I:%M %p')}
        • *Controller:* #{exception.controller_name}##{exception.action_name}
        • *Count:* #{exception_count(exception)}
        #{format_message(exception)}
      TEXT
    end

    def format_message(exception)
      return "" unless exception.message.present?
      
      message = exception.message.truncate(100)
      "• *Message:* `#{message}`"
    end

    def exception_count(exception)
      return 0 unless exception_source

      exception_source
        .where(exception_class: exception.exception_class)
        .where("created_at >= ?", time_range.ago)
        .count
    end

    def no_exceptions_block
      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*✅ No Exceptions in the Last 24 Hours*"
          }
        }
      ]
    end
  end
end