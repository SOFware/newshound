# frozen_string_literal: true

module Newshound
  module Jobs
    class Que < Base
      attr_reader :logger

      def initialize(logger: nil)
        @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
      end

      def queue_statistics
        conn = ActiveRecord::Base.connection
        current_time = conn.quote(Time.now)
        beginning_of_day = conn.quote(Date.today.to_time)

        {
          ready: count_jobs("finished_at IS NULL AND expired_at IS NULL AND run_at <= #{current_time}"),
          scheduled: count_jobs("finished_at IS NULL AND expired_at IS NULL AND run_at > #{current_time}"),
          failed: count_jobs("error_count > 0 AND finished_at IS NULL"),
          finished_today: count_jobs("finished_at >= #{beginning_of_day}")
        }
      rescue => e
        logger.error "Failed to fetch Que statistics: #{e.message}"
        {ready: 0, scheduled: 0, failed: 0, finished_today: 0}
      end

      def job_counts_by_type
        results = ActiveRecord::Base.connection.execute(<<~SQL)
          SELECT job_class, error_count, COUNT(*) as count
          FROM que_jobs
          WHERE finished_at IS NULL
          GROUP BY job_class, error_count
          ORDER BY job_class
        SQL

        results.each_with_object({}) do |row, hash|
          job_class = row["job_class"]
          error_count = row["error_count"].to_i
          count = row["count"].to_i

          hash[job_class] ||= {success: 0, failed: 0, total: 0}

          if error_count.zero?
            hash[job_class][:success] += count
          else
            hash[job_class][:failed] += count
          end

          hash[job_class][:total] += count
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
