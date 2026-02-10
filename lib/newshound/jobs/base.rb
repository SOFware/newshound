# frozen_string_literal: true

module Newshound
  module Jobs
    # Base class for job source adapters
    # Each adapter is responsible for:
    # 1. Fetching queue statistics from its specific job backend
    # 2. Fetching job counts grouped by type
    # 3. Formatting job data for banner display
    #
    # Subclasses must implement:
    # - #queue_statistics - Returns a hash of queue stats
    # - #job_counts_by_type - Returns a hash of job class => counts
    #
    # Unlike Warnings::Base and Exceptions::Base (which format individual records),
    # #format_for_banner takes no arguments and returns aggregate queue statistics.
    # A default implementation is provided that delegates to #queue_statistics.
    class Base
      # Returns queue-level statistics
      #
      # @return [Hash] with keys :ready, :scheduled, :failed, :finished_today
      def queue_statistics
        raise NotImplementedError, "#{self.class} must implement #queue_statistics"
      end

      # Returns job counts grouped by job class
      #
      # @return [Hash] job_class => { success:, failed:, total: }
      def job_counts_by_type
        raise NotImplementedError, "#{self.class} must implement #job_counts_by_type"
      end

      # Returns data formatted for the banner UI
      #
      # @return [Hash] with key :queue_stats containing ready_to_run, scheduled, failed, completed_today
      def format_for_banner
        stats = queue_statistics

        {
          queue_stats: {
            ready_to_run: stats[:ready],
            scheduled: stats[:scheduled],
            failed: stats[:failed],
            completed_today: stats[:finished_today]
          }
        }
      end
    end
  end
end
