# frozen_string_literal: true

module Newshound
  class QueReporter
    attr_reader :job_source, :logger

    def initialize(job_source: nil, logger: nil)
      @job_source = job_source || (defined?(::Que::Job) ? ::Que::Job : nil)
      @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
    end

    def generate_report
      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*📊 Que Jobs Status*"
          }
        },
        job_counts_section,
        queue_health_section
      ].compact
    end
    alias_method :report, :generate_report

    # Returns data formatted for the banner UI
    def banner_data
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

    private

    def job_counts_section
      counts = job_counts_by_type

      return no_jobs_section if counts.empty?

      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: format_job_counts(counts)
        }
      }
    end

    def job_counts_by_type
      return {} unless job_source

      # Use raw SQL since Que::Job may not support ActiveRecord's .group method
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

    def format_job_counts(counts)
      lines = ["*Job Counts by Type:*"]

      counts.each do |job_class, stats|
        status_emoji = (stats[:failed] > 0) ? "⚠️" : "✅"
        lines << "• #{status_emoji} *#{job_class}*: #{stats[:total]} total (#{stats[:success]} success, #{stats[:failed]} failed)"
      end

      lines.join("\n")
    end

    def queue_health_section
      stats = queue_statistics

      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: format_queue_health(stats)
        }
      }
    end

    def queue_statistics
      return default_stats unless job_source

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
      default_stats
    end

    def count_jobs(where_clause)
      ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM que_jobs WHERE #{where_clause}"
      ).to_i
    end

    def default_stats
      {ready: 0, scheduled: 0, failed: 0, finished_today: 0}
    end

    def format_queue_health(stats)
      health_emoji = if stats[:failed] > 10
        "🔴"
      else
        (stats[:failed] > 5) ? "🟡" : "🟢"
      end

      <<~TEXT
        *Queue Health #{health_emoji}*
        • *Ready to Run:* #{stats[:ready]}
        • *Scheduled:* #{stats[:scheduled]}
        • *Failed (Retry Queue):* #{stats[:failed]}
        • *Completed Today:* #{stats[:finished_today]}
      TEXT
    end

    def no_jobs_section
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*No jobs found in the queue*"
        }
      }
    end
  end
end
