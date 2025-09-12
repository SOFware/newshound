# frozen_string_literal: true

require "rails/railtie"

module Newshound
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :newshound do
        desc "Send daily report immediately"
        task report_now: :environment do
          puts "Sending Newshound daily report..."
          Newshound.report!
          puts "Report sent successfully!"
        rescue StandardError => e
          puts "Failed to send report: #{e.message}"
        end

        desc "Schedule daily report job"
        task schedule: :environment do
          puts "Scheduling Newshound daily report..."
          Newshound::Scheduler.run_now!
          puts "Job enqueued successfully!"
        end

        desc "Show current configuration"
        task config: :environment do
          config = Newshound.configuration
          puts "Newshound Configuration:"
          puts "  Enabled: #{config.enabled}"
          puts "  Slack Webhook: #{config.slack_webhook_url.present? ? '[CONFIGURED]' : '[NOT SET]'}"
          puts "  Slack Channel: #{config.slack_channel}"
          puts "  Report Time: #{config.report_time}"
          puts "  Exception Limit: #{config.exception_limit}"
          puts "  Time Zone: #{config.time_zone}"
          puts "  Valid: #{config.valid?}"
        end
      end
    end

    initializer "newshound.configure_que_scheduler" do
      ActiveSupport.on_load(:active_record) do
        if defined?(::Que::Scheduler)
          require_relative "scheduler"
          
          # Add our job to the que-scheduler configuration
          schedule = Newshound::Scheduler.schedule_daily_report
          
          Rails.logger.info "Newshound: Scheduled daily report at #{Newshound.configuration.report_time}"
        else
          Rails.logger.warn "Newshound: que-scheduler not found. Daily reports will need to be triggered manually."
        end
      end
    end

    config.after_initialize do
      if Newshound.configuration.valid?
        Rails.logger.info "Newshound initialized and ready to report!"
      else
        Rails.logger.warn "Newshound is not properly configured. Please check your configuration."
      end
    end
  end
end