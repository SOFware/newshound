module Newshound
  module Exceptions
    # Base class for exception source adapters
    # Each adapter is responsible for:
    # 1. Fetching recent exceptions from its specific exception tracking system
    # 2. Formatting exception data for reports and banners
    #
    # Subclasses must implement:
    # - #recent(time_range:, limit:) - Returns a collection of exception records
    # - #format_for_report(exception) - Formats a single exception for Slack/report display
    # - #format_for_banner(exception) - Formats a single exception for banner UI
    class Base
      # Fetches recent exceptions from the exception tracking system
      #
      # @param time_range [ActiveSupport::Duration] Time duration to look back (e.g., 24.hours)
      # @param limit [Integer] Maximum number of exceptions to return
      # @return [Array] Collection of exception records
      def recent(time_range:, limit:)
        raise NotImplementedError, "#{self.class} must implement #recent"
      end

      # Formats an exception for report/Slack display
      #
      # @param exception [Object] Exception record from the tracking system
      # @param number [Integer] Position number in the list
      # @return [String] Formatted markdown text for display
      def format_for_report(exception, number)
        raise NotImplementedError, "#{self.class} must implement #format_for_report"
      end

      # Formats an exception for banner UI display
      #
      # @param exception [Object] Exception record from the tracking system
      # @return [Hash] Hash with keys: :title, :message, :location, :time
      def format_for_banner(exception)
        raise NotImplementedError, "#{self.class} must implement #format_for_banner"
      end
    end
  end
end
