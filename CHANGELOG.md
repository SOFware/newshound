# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.6] - Unreleased

## [0.2.5] - 2025-12-12

### Added

- Add `Newshound::Warnings` module with registry-based adapter pattern for custom warning sources
- Add `Newshound::Warnings::Base` abstract class for warning adapters
- Add `Newshound::WarningReporter` for fetching and formatting warnings
- Display warnings in banner alongside exceptions and job stats

### Fixed

- Fixed summary badge to show combined warnings and failed jobs count
