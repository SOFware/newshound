# frozen_string_literal: true

module Newshound
  class ExceptionReporter
    attr_reader :exception_source, :configuration, :time_range

    def initialize(exception_source: nil, configuration: nil, time_range: 24.hours)
      @configuration = configuration || Newshound.configuration
      @exception_source = resolve_exception_source(exception_source)
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
    alias_method :report, :generate_report

    # Returns data formatted for the banner UI
    def banner_data
      {
        exceptions: recent_exceptions.map { |exception| exception_source.format_for_banner(exception) }
      }
    end

    private

    def resolve_exception_source(source)
      source ||= @configuration.exception_source
      source.is_a?(Symbol) ? Exceptions.source(source) : source
    end

    def recent_exceptions
      @recent_exceptions ||= exception_source.recent(time_range: time_range, limit: configuration.exception_limit)
    end

    def format_exceptions
      recent_exceptions.map.with_index do |exception, index|
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: exception_source.format_for_report(exception, index + 1)
          }
        }
      end
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
