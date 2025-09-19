# frozen_string_literal: true

require "rails/generators"
require "yaml"

module Newshound
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Configures Newshound for your Rails application"

      def create_initializer
        template "newshound.rb", "config/initializers/newshound.rb"
      end

      def add_to_que_schedule
        que_schedule_path = "config/que_schedule.yml"

        if File.exist?(que_schedule_path)
          say_status :info, "Adding Newshound job to #{que_schedule_path}", :blue

          # Read existing YAML
          existing_config = YAML.load_file(que_schedule_path) || {}

          # Add Newshound job if not already present
          unless existing_config.key?("Newshound::DailyReportJob")
            # Append the configuration to the file
            append_to_file que_schedule_path do
              <<~YAML

                # Newshound daily report job - sends exception and queue reports to Slack
                Newshound::DailyReportJob:
                  cron: "0 9 * * *"  # Daily at 9:00 AM - adjust as needed
                  queue: default
                  args: []
              YAML
            end

            say_status :success, "Added Newshound::DailyReportJob to que_schedule.yml", :green
          else
            say_status :skip, "Newshound::DailyReportJob already exists in que_schedule.yml", :yellow
          end
        else
          say_status :warning, "#{que_schedule_path} not found. Creating it with Newshound job.", :yellow
          create_file que_schedule_path do
            <<~YAML
              # Que-scheduler configuration
              # See https://github.com/hlascelles/que-scheduler for more information

              # Newshound daily report job - sends exception and queue reports to Slack
              Newshound::DailyReportJob:
                cron: "0 9 * * *"  # Daily at 9:00 AM - adjust as needed
                queue: default
                args: []
            YAML
          end
        end
      end

      def display_post_install_message
        say ""
        say "===============================================================================", :green
        say "  Newshound has been successfully installed!", :green
        say ""
        say "  Next steps:", :yellow
        say "  1. Configure your Slack webhook URL in config/initializers/newshound.rb"
        say "  2. Adjust the report schedule in config/que_schedule.yml if needed"
        say "  3. Restart your Rails server and Que workers"
        say ""
        say "  To test your configuration, run:", :cyan
        say "    rails runner 'Newshound.report!'"
        say ""
        say "  For more information, visit:", :blue
        say "    https://github.com/salbanez/newshound"
        say "===============================================================================", :green
        say ""
      end
    end
  end
end