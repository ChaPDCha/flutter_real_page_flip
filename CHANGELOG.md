# Changelog

All notable changes to this project will be documented in this file.

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
