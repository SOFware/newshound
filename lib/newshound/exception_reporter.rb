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
    alias_method :report, :generate_report

    # Returns data formatted for the banner UI
    def banner_data
      {
        exceptions: recent_exceptions.map { |exception| format_exception_for_banner(exception) }
      }
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
      details = parse_exception_details(exception)

      <<~TEXT
        *#{number}. #{exception_title(exception)}*
        • *Time:* #{exception.created_at.strftime('%I:%M %p')}
        #{format_controller(details)}
        #{format_message(exception, details)}
      TEXT
    end

    def exception_title(exception)
      if exception.respond_to?(:title) && exception.title.present?
        exception.title
      elsif exception.respond_to?(:exception_class) && exception.exception_class.present?
        exception.exception_class
      else
        "Unknown Exception"
      end
    end

    def parse_exception_details(exception)
      return {} unless exception.respond_to?(:body) && exception.body.present?

      JSON.parse(exception.body)
    rescue JSON::ParserError
      {}
    end

    def format_controller(details)
      return String.new unless details["controller_name"] && details["action_name"]

      "• *Controller:* #{details['controller_name']}##{details['action_name']}\n"
    end

    def format_message(exception, details = nil)
      details ||= parse_exception_details(exception)

      # Try to get message from different sources
      message = if details["message"].present?
        details["message"]
      elsif exception.respond_to?(:message) && exception.message.present?
        exception.message
      end

      return String.new unless message.present?

      message = message.to_s.truncate(100)
      "• *Message:* `#{message}`"
    end

    def exception_count(exception)
      return 0 unless exception_source

      # Use title for exception-track, exception_class for other systems
      if exception.respond_to?(:title) && exception.title.present?
        exception_source
          .where(title: exception.title)
          .where("created_at >= ?", time_range.ago)
          .count
      elsif exception.respond_to?(:exception_class)
        exception_source
          .where(exception_class: exception.exception_class)
          .where("created_at >= ?", time_range.ago)
          .count
      else
        0
      end
    end

    def format_exception_for_banner(exception)
      details = parse_exception_details(exception)

      # Extract message
      message = if details["message"].present?
        details["message"].to_s
      elsif exception.respond_to?(:message) && exception.message.present?
        exception.message.to_s
      else
        String.new
      end

      # Extract location
      location = if details["controller_name"] && details["action_name"]
        "#{details['controller_name']}##{details['action_name']}"
      else
        String.new
      end

      {
        title: exception_title(exception),
        message: message.truncate(100),
        location: location,
        time: exception.created_at.strftime('%I:%M %p')
      }
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