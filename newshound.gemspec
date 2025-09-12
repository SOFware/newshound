# frozen_string_literal: true

require_relative "lib/newshound/version"

Gem::Specification.new do |spec|
  spec.name = "newshound"
  spec.version = Newshound::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Daily Slack reporter for Que jobs status and exception tracking"
  spec.description = "Newshound sniffs out exceptions and job statuses in your Rails app and reports them daily to Slack"
  spec.homepage = "https://github.com/yourusername/newshound"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "slack-ruby-client", "~> 2.0"
  spec.add_dependency "que", ">= 1.0"
  spec.add_dependency "que-scheduler", ">= 4.0"
  spec.add_dependency "exception-track", ">= 0.1"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "pg"
end