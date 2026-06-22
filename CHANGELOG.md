# Changelog

All notable changes to the `real_page_flip` **package** will be documented here.
For the example application (Realbook app), see [example/CHANGELOG.md](example/CHANGELOG.md).

## [1.6.0] - 2026-06-22
### Added
- `DevicePerformanceProfile` enum (high/medium/low) for adaptive rendering quality.
- `performanceProfile` field on `PageFlipConfig` and `PageFlipLayerView`.
- `DefaultPageFlipEffectHandler` now accepts an optional `performanceProfile` to throttle haptic feedback on low-end devices.

### Fixed
- Single-page backward flip: corrected `flapRightOfFold` to `false` for single-page mode so the flap extends left from foldX (consistent with forward direction).
- `flapSnapshotSpreadIndex` now returns `currentIndex - 1` for single backward (previously returned `currentIndex`), ensuring the correct snap page is displayed as the flap texture.

## [1.5.1] - 2026-06-21
### Changed
- Split page flip engine library into part files (`page_flip_geometry.dart`, `page_flip_gesture.dart`) for cleaner code organization.
- Fixed 12 dart compiler/linter warnings in page flip engine and widgets.

## [1.5.0] - 2026-06-21
### Added
- `flapRightOfFold` field on `PageFlipGeometry` unifying four-mode flap-direction logic.
- Single-page backward: spine-anchored fold with flap following finger direction.
- Direction-aware highlight, fold-darkening, edge-fade, and fold-fade gradients.

### Changed
- Single-page forward: `foldX` anchored at left spine (x=0), flap extends rightward, shrinking toward spine as page turns.
- Double-spread backward: flap extends RIGHT of foldX (previously left).
- `buildFlapScreenClipPath` supports flap-right-of-fold paths with corrected bleed.
- Angle limits simplified for single-page mode.

### Fixed
- Backward single-page flap now shows page content during flip.
- Backward flap curvature direction corrected.
- Clip bleed direction corrected for backward double-spread.
- Single-page fold line no longer moves to opposite edge (eliminated tearing look).

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
