# frozen_string_literal: true

module Newshound
  class Scheduler
    def self.schedule_daily_report
      return unless defined?(::Que::Scheduler)

      config = Newshound.configuration
      return unless config.valid?

      # Note: Que-scheduler uses a YAML config file (config/que_schedule.yml)
      # This method returns the configuration that should be added to that file
      # or can be used to manually schedule the job
      schedule_config = {
        "newshound_daily_report" => {
          "class" => "Newshound::DailyReportJob",
          "cron" => build_cron_expression(config.report_time),
          "queue" => "default",
          "args" => []
        }
      }

      # Log the configuration for visibility
      if defined?(Rails) && Rails.logger
        Rails.logger.info "Newshound daily report scheduled for #{config.report_time} (cron: #{schedule_config['newshound_daily_report']['cron']})"
      end

      schedule_config
    end

    def self.build_cron_expression(time_string)
      # Convert "09:00" format to cron expression
      # Format: minute hour * * *
      hour, minute = time_string.split(":").map(&:to_i)
      "#{minute} #{hour} * * *"
    end

    def self.run_now!
      Newshound::DailyReportJob.enqueue
    end
  end
end