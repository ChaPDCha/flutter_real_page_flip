# Changelog

All notable changes to the `real_page_flip` **package** will be documented here.
For the example application (Realbook app), see [example/CHANGELOG.md](example/CHANGELOG.md).

## [1.4.2] - 2026-06-04
### Added
- Updated documentation to clarify that the engine is optimized for vertical mobile devices and does not support horizontal two-page view.

## [1.4.1] - 2026-06-04
### Changed
- Relicensed the package under the MIT License.

## [1.4.0] - 2026-05-14
### Added
- Direction-aware flip thresholds: `cutoffForward` and `cutoffPrevious` independently control drag-release completion.
- 12 new test files covering geometry, physics, controllers, and widgets.
- Named geometry constants extracted from inline magic numbers.

### Changed
- `PageFlipStateController` accepts configurable thresholds from `PageFlipConfig`.
- `PageFlipPainter` constructor is now `const`.
- `cutoffForward` default: 0.8 → 0.4, `cutoffPrevious` default: 0.1 → 0.4.

### Fixed
- `PageFlipConfig`, `PaperPhysicsConfig`, `PaperPhysicsFrame` equality/hashCode.

## [1.3.0] - 2026-05-09
### Added
- Dark Mode Support: `PageFlipConfig.backgroundColor` now defaults to `null` and reads `Theme.of(context).scaffoldBackgroundColor` at render time.
- Adaptive shadow intensity for dark backgrounds.

### Changed
- `PageFlipConfig.backgroundColor` type: `Color` → `Color?`.

## [1.2.4] - 2026-05-02
### Fixed
- Fixed 404 error on legacy interaction demo video URL.

## [1.2.3] - 2026-05-02
### Fixed
- Replaced WebP tags with raw markdown video links for pub.dev compatibility.

## [1.2.2] - 2026-05-02
### Fixed
- Fixed broken video tags on pub.dev.

## [1.2.1] - 2026-05-02
### Added
- High-fidelity extended interaction recording.
- Legacy Interaction Demo section.

## [1.2.0] - 2026-05-02
### Added
- Production-quality demo assets.
- Optimized README for pub.dev.

## [1.1.3] - 2026-05-02
### Added
- High-fidelity interaction recording of the actual engine.

## [1.1.2] - 2026-05-02
### Added
- Snappy demo video with immediate interaction start.
- Absolute asset URLs for pub.dev compatibility.

## [1.1.1] - 2026-05-02
### Added
- Professional teaser video, GPU optimization guides, Opus audio assets.
- Example app with unique content and stress tests.

## [1.1.0] - 2026-05-01
### Added
- Physics-based paper friction interaction logic.
- Dynamic geometry rendering with hardware-accelerated clipping.
- Integrated haptic feedback and sound effect system.
- Semantics support for accessibility.

### Changed
- Refactored `PageFlipWidget` to use `PageFlipStateController`.
- Improved snapshot capturing in `PreRenderManager`.

### Fixed
- Layout boundary issues in Stack configurations.
- Memory leak in `PreRenderManager` snapshots.
