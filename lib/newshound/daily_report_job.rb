# frozen_string_literal: true

module Newshound
  if defined?(::Que::Job)
    class DailyReportJob < ::Que::Job
      def run
        return unless Newshound.configuration.valid?

        Newshound.report!

        destroy
      rescue StandardError => e
        Rails.logger.error "Newshound::DailyReportJob failed: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")

        # Re-raise to let Que handle retry logic
        raise
      end
    end
  else
    class DailyReportJob
      def self.enqueue(*args)
        Rails.logger.warn "Que is not available. DailyReportJob cannot be enqueued."
      end

      def run
        Rails.logger.warn "Que is not available. DailyReportJob cannot be run."
      end
    end
  end
end