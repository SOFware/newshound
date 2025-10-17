# frozen_string_literal: true

require "rails/generators"

module Newshound
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Configures Newshound for your Rails application"

      def create_initializer
        template "newshound.rb", "config/initializers/newshound.rb"
      end

      def display_post_install_message
        say ""
        say "===============================================================================", :green
        say "  Newshound has been successfully installed!", :green
        say ""
        say "  Next steps:", :yellow
        say "  1. Configure authorized roles in config/initializers/newshound.rb"
        say "  2. Make sure your User model has a role attribute (or customize authorization)"
        say "  3. Restart your Rails server"
        say ""
        say "  The Newshound banner will automatically appear at the top of pages for"
        say "  authorized users (developers and super_users by default)."
        say ""
        say "  To test the reporters, run:", :cyan
        say "    rake newshound:test_exceptions"
        say "    rake newshound:test_jobs"
        say ""
        say "  For more information, visit:", :blue
        say "    https://github.com/salbanez/newshound"
        say "===============================================================================", :green
        say ""
      end
    end
  end
end