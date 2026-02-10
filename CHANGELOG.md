# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.8] - 2026-02-10

### Changed

- Ruby support to 3.3+ and added Ruby 4.0 to CI matrix (24e5b86)
- Job monitoring uses configurable adapter pattern via config.job_source (8d33d30)

### Removed

- Ruby 3.1 and 3.2 support (24e5b86)
- Hard dependency on que gem (8d33d30)
- QueReporter class (replaced by JobReporter + Jobs adapters) Version: major (8d33d30)

### Fixed

- Set the correct location for the repository on the web. (cb7bb88)
- test_exceptions rake task calling report instead of banner_data (e440188)
- Banner overlaying content in apps with !important body padding-top rules (16f22f1)

### Added

- Jobs adapter pattern with Base class and registry (c50ba9c)
- Jobs::Que adapter for Que job backend (c50ba9c)
- JobReporter that delegates to a configurable job source adapter (c50ba9c)
- ExceptionReporter#formatted_exception_count and #exception_summary helpers (e440188)

## [0.2.7] - 2026-01-30
