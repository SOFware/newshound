# frozen_string_literal: true

require "rails/railtie"

module Newshound
  class Railtie < Rails::Railtie
    # Register middleware to inject banner
    initializer "newshound.middleware" do |app|
      if Newshound.configuration.enabled
        app.middleware.use Newshound::Middleware::BannerInjector
      end
    end

    rake_tasks do
      namespace :newshound do
        desc "Show current configuration"
        task config: :environment do
          config = Newshound.configuration
          puts "Newshound Configuration:"
          puts "  Enabled: #{config.enabled}"
          puts "  Exception Limit: #{config.exception_limit}"
          puts "  Authorized Roles: #{config.authorized_roles.join(', ')}"
          puts "  Current User Method: #{config.current_user_method}"
          puts "  Custom Authorization: #{config.authorization_block.present? ? 'Yes' : 'No'}"
        end

        desc "Test exception reporter"
        task test_exceptions: :environment do
          reporter = Newshound::ExceptionReporter.new
          data = reporter.report
          puts "Exception Report:"
          puts "  Total exceptions: #{data[:exceptions]&.length || 0}"
          data[:exceptions]&.each_with_index do |ex, i|
            puts "  #{i + 1}. #{ex[:title]} - #{ex[:message]}"
          end
        end

        desc "Test job reporter"
        task test_jobs: :environment do
          reporter = Newshound::QueReporter.new
          data = reporter.report
          puts "Job Queue Report:"
          puts "  Ready to run: #{data.dig(:queue_stats, :ready_to_run)}"
          puts "  Scheduled: #{data.dig(:queue_stats, :scheduled)}"
          puts "  Failed: #{data.dig(:queue_stats, :failed)}"
          puts "  Completed today: #{data.dig(:queue_stats, :completed_today)}"
        end
      end
    end

    config.after_initialize do
      if Newshound.configuration.valid?
        Rails.logger.info "Newshound initialized - banner will be shown to authorized users"
      else
        Rails.logger.warn "Newshound is disabled"
      end
    end
  end
end