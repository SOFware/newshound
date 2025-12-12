# frozen_string_literal: true

module Newshound
  module Warnings
    # Base class for warning source adapters
    # Each adapter is responsible for:
    # 1. Fetching recent warnings from its specific data source
    # 2. Formatting warning data for reports and banners
    #
    # Subclasses must implement:
    # - #recent(time_range:, limit:) - Returns a collection of warning records
    # - #format_for_report(warning, number) - Formats a single warning for Slack/report display
    # - #format_for_banner(warning) - Formats a single warning for banner UI
    class Base
      # Fetches recent warnings from the data source
      #
      # @param time_range [ActiveSupport::Duration] Time duration to look back (e.g., 24.hours)
      # @param limit [Integer] Maximum number of warnings to return
      # @return [Array] Collection of warning records
      def recent(time_range:, limit:)
        raise NotImplementedError, "#{self.class} must implement #recent"
      end

      # Formats a warning for report/Slack display
      #
      # @param warning [Object] Warning record from the data source
      # @param number [Integer] Position number in the list
      # @return [String] Formatted markdown text for display
      def format_for_report(warning, number)
        raise NotImplementedError, "#{self.class} must implement #format_for_report"
      end

      # Formats a warning for banner UI display
      #
      # @param warning [Object] Warning record from the data source
      # @return [Hash] Hash with keys: :title, :message, :location, :time
      def format_for_banner(warning)
        raise NotImplementedError, "#{self.class} must implement #format_for_banner"
      end
    end
  end
end
