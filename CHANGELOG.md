# Changelog

All notable changes to this project will be documented in this file.

## [1.1.2] - 2026-05-02
### Added
- Improved snappy demo video with immediate interaction start (zero delay).
- Switched to absolute asset URLs in documentation for better rendering on pub.dev and other platforms.

## [1.1.1] - 2026-05-02
### Added
- Professional high-fidelity teaser video (demo.webp) for documentation.
- Comprehensive technical differentiation and GPU optimization guides in README.
- Standardized high-efficiency Opus audio assets for better performance.
- Enhanced example application with unique page content and heavy-load stress tests.
- GitHub repository SEO optimization (topics, description).

### Fixed
- Sync issues between internal package and public repository.

## [1.1.0] - 2026-05-01
### Added
- Physics-based interaction logic for realistic paper friction.
- Dynamic geometry rendering with hardware-accelerated clipping.
- Integrated haptic feedback system.
- Sound effect integration with `audioplayers`.
- Semantics support for accessibility.
- Strict linting and code formatting.

### Changed
- Refactored `PageFlipWidget` to use a more robust `PageFlipStateController`.
- Improved snapshot capturing logic in `PreRenderManager`.

### Fixed
- Layout boundary issues in certain `Stack` configurations.
- Memory leak in `PreRenderManager` snapshots.
