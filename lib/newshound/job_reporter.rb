# frozen_string_literal: true

module Newshound
  class JobReporter
    attr_reader :job_source, :configuration, :logger

    def initialize(job_source: nil, configuration: nil, logger: nil)
      @configuration = configuration || Newshound.configuration
      @job_source = resolve_job_source(job_source)
      @logger = logger || (defined?(Rails) ? Rails.logger : Logger.new($stdout))
    end

    def generate_report
      return no_jobs_block unless job_source

      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*📊 Job Queue Status*"
          }
        },
        job_counts_section,
        queue_health_section
      ].compact
    end
    alias_method :report, :generate_report

    def banner_data
      return {queue_stats: {}} unless job_source

      job_source.format_for_banner
    end

    private

    def resolve_job_source(source)
      source ||= @configuration.job_source
      return nil if source.nil?

      source.is_a?(Symbol) ? Jobs.source(source) : source
    end

    def job_counts_section
      counts = job_source.job_counts_by_type

      return no_jobs_section if counts.empty?

      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: format_job_counts(counts)
        }
      }
    end

    def format_job_counts(counts)
      lines = ["*Job Counts by Type:*"]

      counts.each do |job_class, stats|
        breakdown = "#{stats[:success]} success, #{stats[:failing].to_i} failing, #{stats[:expired].to_i} expired"
        lines << "• #{job_status_emoji(stats)} *#{job_class}*: #{stats[:total]} total (#{breakdown})"
      end

      lines.join("\n")
    end

    def job_status_emoji(stats)
      return "⚠️" if stats[:expired].to_i > 0
      return "🟡" if stats[:failing].to_i > 0

      "✅"
    end

    def queue_health_section
      stats = job_source.queue_statistics

      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: format_queue_health(stats)
        }
      }
    end

    def format_queue_health(stats)
      failing = stats[:failing].to_i
      expired = stats[:expired].to_i

      health_emoji = if expired > 0
        "🔴"
      else
        (failing > 0) ? "🟡" : "🟢"
      end

      <<~TEXT
        *Queue Health #{health_emoji}*
        • *Ready to Run:* #{stats[:ready]}
        • *Scheduled:* #{stats[:scheduled]}
        • *Failing (Will Retry):* #{failing}
        • *Expired (Out of Retries):* #{expired}
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

    def no_jobs_block
      [
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "*✅ No Job Source Configured*"
          }
        }
      ]
    end
  end
end
