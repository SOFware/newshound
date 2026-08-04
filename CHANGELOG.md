# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.1] - Unreleased

## [1.1.0] - 2026-08-04

### Added

- config.position option for pinning the banner to the bottom of the viewport (1350e11)
- Separate failing and expired job counts (a6957bd)
- Close button that clears the banner from the current page (b6d3330)

### Changed

- Banner CSS uses flat per-element classes instead of nested selectors (a75c3cd)
- Banner state classes renamed to newshound-banner-collapsed and newshound-banner-minimized (7e95fac)
- The banner alerts on expired jobs only, not ones still retrying (a6957bd)
- failed_jobs_threshold is now expired_jobs_threshold, with an alias (a6957bd)

### Fixed

- Minimizing no longer leaves an empty strip where the banner was (b6d3330)
- Resolved errors no longer appear in the banner (b80e8c9)
- Repeat occurrences of one error collapse to a single row (b80e8c9)
- Minimizing no longer hides the banner from genuinely new problems (57dbdf5)
