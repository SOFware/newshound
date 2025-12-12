# frozen_string_literal: true

module Newshound
  class WarningReporter
    attr_reader :warning_source, :configuration, :time_range

    def initialize(warning_source: nil, configuration: nil, time_range: 24.hours)
      @configuration = configuration || Newshound.configuration
      @warning_source = resolve_warning_source(warning_source)
      @time_range = time_range
    end

    def generate_report
      return no_warnings_block if recent_warnings.empty?

      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*⚠️ Recent Warnings (Last 24 Hours)*"
          }
        },
        *format_warnings
      ]
    end
    alias_method :report, :generate_report

    # Returns data formatted for the banner UI
    def banner_data
      return {warnings: []} unless warning_source

      {
        warnings: recent_warnings.map { |warning| warning_source.format_for_banner(warning) }
      }
    end

    private

    def resolve_warning_source(source)
      source ||= @configuration.warning_source
      return nil if source.nil?

      source.is_a?(Symbol) ? Warnings.source(source) : source
    end

    def recent_warnings
      return [] unless warning_source

      @recent_warnings ||= warning_source.recent(
        time_range: time_range,
        limit: configuration.warning_limit
      )
    end

    def format_warnings
      recent_warnings.map.with_index do |warning, index|
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: warning_source.format_for_report(warning, index + 1)
          }
        }
      end
    end

    def no_warnings_block
      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*✅ No Warnings in the Last 24 Hours*"
          }
        }
      ]
    end
  end
end
