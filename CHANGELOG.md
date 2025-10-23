# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.2] - 2025-10-23

### Added

- CI workflow to run tests on Ruby 3.0-3.4 (b3ebc7a)
- Separate linter job for RuboCop (b3ebc7a)
- Coverage reporting with SimpleCov (b3ebc7a)
- CI workflow to run tests on Ruby 3.0-3.4 (782cc57)
- Separate linter job for RuboCop (782cc57)
- Coverage reporting with SimpleCov (782cc57)
- .claude/settings.local.json to .gitignore (701d802)
- Reissue gem dependency for automated versioning (feac98a)
- Git trailer support for changelog management (feac98a)
- Initial CHANGELOG.md with Keep a Changelog format (feac98a)
- CODEOWNERS file for SOFware/engineers (1a0a1f5)
- Newshound::Exceptions::Base for standard API to interact with exception data (9dce846)
- Configuration exception_source to allow for future alternative exception backends (9dce846)
- SolidErrors support (8b5b48a)

### Changed

- Replaced RuboCop with StandardRB for simpler linting (09292ed)
- Updated GitHub Actions workflow to use standardrb (09292ed)
- Auto-corrected all StandardRB violations (09292ed)
- Simplified test setup by removing unused mocks (701d802)
- Rakefile to use reissue tasks instead of manual versioning (feac98a)
- Removed Ruby 3.0 from test matrix (now testing 3.1-3.4) (4beafd2)
- Updated gemspec required_ruby_version to >= 3.1.0 (4beafd2)

### Fixed

- Workflow now only runs once per PR (removed duplicate triggers) (09292ed)
- Mock ActiveRecord::Base.connection and its methods (701d802)
- Mock connection.execute to return database-like results (701d802)
- Mock connection.quote and connection.select_value properly (701d802)
- Name and email in gemspec authors (ab44f30)

### Removed

- Dependency on exception-track (8b5b48a)

## [0.2.2] - Unreleased
