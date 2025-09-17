# frozen_string_literal: true

module Newshound
  class QueReporter
    attr_reader :job_source, :logger

    def initialize(job_source: nil, logger: nil)
      @job_source = job_source || (defined?(::Que::Job) ? ::Que::Job : nil)
      @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new(STDOUT))
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

      job_source
        .group(:job_class)
        .group(:error_count)
        .count
        .each_with_object({}) do |((job_class, error_count), count), hash|
          hash[job_class] ||= { success: 0, failed: 0, total: 0 }
          
          if error_count.zero?
            hash[job_class][:success] += count
          else
            hash[job_class][:failed] += count
          end
          
          hash[job_class][:total] += count
        end
    end

    def format_job_counts(counts)
      lines = ["*Job Counts by Type:*"]
      
      counts.each do |job_class, stats|
        status_emoji = stats[:failed] > 0 ? "⚠️" : "✅"
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

      current_time = Time.now
      beginning_of_day = Date.today.to_time

      {
        ready: job_source.where(finished_at: nil, expired_at: nil).where("run_at <= ?", current_time).count,
        scheduled: job_source.where(finished_at: nil, expired_at: nil).where("run_at > ?", current_time).count,
        failed: job_source.where.not(error_count: 0).where(finished_at: nil).count,
        finished_today: job_source.where("finished_at >= ?", beginning_of_day).count
      }
    rescue StandardError => e
      logger.error "Failed to fetch Que statistics: #{e.message}"
      default_stats
    end

    def default_stats
      { ready: 0, scheduled: 0, failed: 0, finished_today: 0 }
    end

    def format_queue_health(stats)
      health_emoji = stats[:failed] > 10 ? "🔴" : stats[:failed] > 5 ? "🟡" : "🟢"
      
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