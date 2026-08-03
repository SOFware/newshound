# frozen_string_literal: true

module Newshound
  module Jobs
    class Que < Base
      attr_reader :logger

      def initialize(logger: nil)
        @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
      end

      # Que separates two trouble states: a failing job has errored but still has
      # retries left, an expired job has run out of them and needs a human. :failed
      # is the union of the two, kept for callers written before the split.
      def queue_statistics
        conn = ActiveRecord::Base.connection
        current_time = conn.quote(Time.now)
        beginning_of_day = conn.quote(Date.today.to_time)

        {
          ready: count_jobs("finished_at IS NULL AND expired_at IS NULL AND run_at <= #{current_time}"),
          scheduled: count_jobs("finished_at IS NULL AND expired_at IS NULL AND run_at > #{current_time}"),
          failing: count_jobs("error_count > 0 AND finished_at IS NULL AND expired_at IS NULL"),
          expired: count_jobs("expired_at IS NOT NULL"),
          failed: count_jobs("error_count > 0 AND finished_at IS NULL"),
          finished_today: count_jobs("finished_at >= #{beginning_of_day}")
        }
      rescue => e
        logger.error "Failed to fetch Que statistics: #{e.message}"
        {ready: 0, scheduled: 0, failing: 0, expired: 0, failed: 0, finished_today: 0}
      end

      def job_counts_by_type
        results = ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT job_class,
                 COUNT(*) FILTER (WHERE error_count = 0 AND expired_at IS NULL) AS success,
                 COUNT(*) FILTER (WHERE error_count > 0 AND expired_at IS NULL) AS failing,
                 COUNT(*) FILTER (WHERE expired_at IS NOT NULL) AS expired,
                 COUNT(*) AS total
          FROM que_jobs
          WHERE finished_at IS NULL
          GROUP BY job_class
          ORDER BY job_class
        SQL

        results.each_with_object({}) do |row, hash|
          failing = row["failing"].to_i
          expired = row["expired"].to_i

          hash[row["job_class"]] = {
            success: row["success"].to_i,
            failing:,
            expired:,
            failed: failing + expired,
            total: row["total"].to_i
          }
        end
      rescue => e
        logger.error "Failed to fetch job counts: #{e.message}"
        {}
      end

      private

      def count_jobs(where_clause)
        ActiveRecord::Base.connection.select_value(
          "SELECT COUNT(*) FROM que_jobs WHERE #{where_clause}"
        ).to_i
      end
    end
  end
end
