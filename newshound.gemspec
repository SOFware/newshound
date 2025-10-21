# frozen_string_literal: true

require_relative "lib/newshound/version"

Gem::Specification.new do |spec|
  spec.name = "newshound"
  spec.version = Newshound::VERSION
  spec.authors = ["salbanez"]
  spec.email = ["salbanez@example.com"]

  spec.summary = "Real-time web UI banner for monitoring Que jobs and exception tracking"
  spec.description = "Newshound displays exceptions and job statuses in a collapsible banner for authorized users in your Rails app"
  spec.homepage = "https://github.com/salbanez/newshound"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

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
  spec.add_dependency "que", ">= 1.0"
  spec.add_dependency "exception-track", ">= 0.1"
end
