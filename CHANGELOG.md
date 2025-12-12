# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.5] - Unreleased

### Added

- Add `Newshound::Warnings` module with registry-based adapter pattern for custom warning sources
- Add `Newshound::Warnings::Base` abstract class for warning adapters
- Add `Newshound::WarningReporter` for fetching and formatting warnings
- Display warnings in banner alongside exceptions and job stats

### Fixed

- Fixed summary badge to show combined warnings and failed jobs count

## [0.2.4] - 2025-12-12

### Fixed

- Fixed release workflow to properly create version bump PRs using gh pr create instead of peter-evans/create-pull-request action, resolving compatibility issue with reissue gem

## [0.2.3] - 2025-10-29

### Fixed

- Updated styling in banner injector to attempt to keep newshound banner above other application's menus, instead of hovering over them.

### Changed

- Consolidated exception data extraction in ExceptionTrack and SolidErrors (55cffd3)
