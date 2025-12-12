# frozen_string_literal: true

require "bundler/gem_tasks"
require "reissue/gem"
require "rspec/core/rake_task"
require "standard/rake"

Reissue::Task.create :reissue do |task|
  task.version_file = "lib/newshound/version.rb"
  task.fragment = :git
  task.commit_finalize = false # Let workflow handle commits
end

RSpec::Core::RakeTask.new(:spec)

task default: %i[spec standard]
