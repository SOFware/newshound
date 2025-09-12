# frozen_string_literal: true

module Newshound
  class Scheduler
    def self.schedule_daily_report
      return unless defined?(::Que::Scheduler)
      
      config = Newshound.configuration
      return unless config.valid?
      
      # Schedule the job using que-scheduler
      # This will be picked up by que-scheduler's configuration
      schedule_config = {
        "newshound_daily_report" => {
          "class" => "Newshound::DailyReportJob",
          "cron" => build_cron_expression(config.report_time),
          "queue" => "default",
          "args" => []
        }
      }
      
      # Merge with existing schedule if any
      if defined?(::Que::Scheduler.configuration)
        ::Que::Scheduler.configuration.merge!(schedule_config)
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