# Changelog

All notable changes to this project will be documented in this file.

## [1.2.2] - 2026-05-02
### Fixed
- Fixed broken video tags on pub.dev by replacing them with clickable animated WebP thumbnails and Markdown text links.
- Removed redundant demo sections to ensure exactly two primary demo links are prominently displayed.

## [1.2.1] - 2026-05-02
### Added
- Replaced main demo with a high-fidelity, extended interaction recording.
- Added "Legacy Interaction Demo" section to showcase core physics and gesture arbitration.
- Integrated direct GitHub user-attachment URLs for robust documentation rendering.

## [1.2.0] - 2026-05-02
### Added
- Replaced demo assets with high-fidelity production sample (`realpageflip_sample.webp`).
- Optimized `README` for pub.dev compatibility with clickable high-resolution previews.
- Increased image width in documentation for better technical visualization.

## [1.1.3] - 2026-05-02
### Added
- Replaced static placeholder with a high-fidelity interaction recording of the actual engine.
- Fixed rendering issues in the documentation preview assets.

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
