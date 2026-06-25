# Changelog

All notable changes to the `real_page_flip` **package** will be documented here.
For the example application (Realbook app), see [example/CHANGELOG.md](example/CHANGELOG.md).

## [1.8.0] - 2026-06-25
### ✨ 기능
- PaperTexturePreset 모델 추가 (smooth/standard/textured/kraft)
- PageFlipConfig에 hapticTexturePreset 설정 연동

### ⚡ 성능
- TXT 파일 인코딩 탐지 개선 (UTF-8 BOM → UTF-8 → latin1 fallback)

## [1.7.2] - 2026-06-24
### Changed
- Extracted `PageFlipPainter` and `PageFlipClippers` into separate part files for
  cleaner code organization.
- Haptic engine enhancements:
  - iOS/Android platform-specific texture haptic paths with speed-adaptive throttling.
  - Weber-Fechner non-linear amplitude curve (pow 1.3-1.4) for slip-release and
    micro-slip events.
  - Independent iOS/Android texture tick throttle tracking.

## [1.7.1] - 2026-06-24
### Changed
- Haptic engine redesigned with event-specific vibration signatures:
  - `startHaptic`: single 45ms pulse at amplitude 180
  - `impulseHaptic`: crisp double-tap pattern for tap-flip confirmation
  - `slipRelease`: intensity-based double-tap pattern (pages slipping feel)
  - `microSlip`: intensity-based single pulse (acceleration bursts)
  - `sound`: 28ms pulse synchronized with audio
  - `texturedHaptic`: duration reduced to 10-30ms for cleaner throttle separation
- Added `_vibratePattern()` using `Vibration.vibrate(pattern:, intensities:)` for
  multi-pulse haptic sequences on amplitude-control-capable devices
- Added `_iosHaptic()` / `_cancelHaptic()` primitives
- Removed `_triggerImpact()` / `HapticImpactType` in favour of event-specific handlers
- Stick-slip events now use their `intensity` field (0.0-1.0) to dynamically scale
  vibration duration and amplitude instead of hardcoded light/medium presets

## [1.7.0] - 2026-06-23
### Added
- `DefaultPageFlipEffectHandler` is now exported from the public API
  (`package:real_page_flip/real_page_flip.dart`)

### Fixed
- `_triggerImpact()` now fires `Vibration.vibrate()` after `HapticFeedback`,
  ensuring haptic vibration is actually felt on Android devices where
  `HapticFeedback` is too subtle or imperceptible. Impact events
  (startHaptic, impulseHaptic) now produce real motor vibration.
- Non-amplitude-control Android devices now use `Vibration.vibrate(duration:)`
  instead of `HapticFeedback.selectionClick()` during paper-texture haptics
  (texturedHaptic), providing noticeably stronger feedback.
- Duration clamp raised from 5-20ms to 8-35ms so paper-texture vibration
  pulses are long enough to feel.

## [1.6.2] - 2026-06-23
### Changed
- Minor style and formatting lint fixes to pass strict quality gate standards.

## [1.6.1] - 2026-06-23
### Fixed
- Single backward page flip: unified `foldX` and `flapMaterialWidth` formulas with forward direction. Now single backward foldX moves right-to-left (same as forward) and flap grows with progress, eliminating directional inconsistency.

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
