# Changelog

All notable changes to the `real_page_flip` **package** will be documented here.
For the example application (Realbook app), see [example/CHANGELOG.md](example/CHANGELOG.md).

## [1.9.6] - 2026-06-28
### ♻️ 리팩토링
- `PageFlipGeometry`의 모든 `late final` 필드를 `final` + factory constructor로 전환하여 `LateInitializationError` 위험 제거 | Converted 22 `late final` fields to plain `final` via factory constructor, eliminating `LateInitializationError` risk
### 🐛 수정
- 정적 Shader 캐시(`static Map<String, Shader>`)가 절대 dispose되지 않아 GPU 메모리가 단조 증가하던 누수 수정. 인라인 `createShader`로 대체 | Fixed unbounded GPU memory leak from static Shader cache — inlined simple gradient creation instead
- `build()` 내 `addPostFrameCallback`이 LayoutBuilder 재호출 시 중복 등록되어 `updateCachedWidth`/`captureSnapshots`가 여러 번 실행되던 버그 수정 | Fixed stacked post-frame callbacks in `build()` causing redundant `updateCachedWidth`/`captureSnapshots`
- snapshot 부재 시 `Offstage`의 child가 단색 paper로 교체되어 capture pipeline이 영구 손상되던 문제 수정 (liveFallbackIndices 제거) | Fixed snapshot pipeline corruption where missing snapshots caused Offstage to render paper instead of live pages (removed liveFallbackIndices)
- `_scheduleCaptureRetry`의 단일 스칼라 필드가 덮어써져 잘못된 파라미터로 retry되던 버그 수정 | Fixed capture retry parameter overwrite bug in `_scheduleCaptureRetry`
- 드래그 수용 후 수직 제스처를 거부할 수 없어 Scrollable/SelectableText가 block되던 문제 수정 | Fixed post-accept vertical gesture rejection so Scrollable/SelectableText can receive scrolls

## [1.9.5] - 2026-06-28
### 🐛 수정
- 위젯 소멸 및 제스처 레이어 언마운트 시점에 발생할 수 있는 Null check 및 lifecycle 크래시 방지 | Guarded against null safety/lifecycle crashes during unmounting and disposal
- 화면 크기 변경 시 캐시 무효화 및 레이아웃 재계산 처리 추가 | Added cache invalidation and layout recalculation on size changes
- `endRevealStrength` 기본값을 `0.0`으로 변경하고, settling 단계에서의 미세 비주얼 잔상 개선을 위해 중간 레이어 fade transition 추가 | Changed `endRevealStrength` default to `0.0` and added middle layer fade transition to eliminate settled artifacts
- `flapContentRevealStart/End` 분모 0 억제 처리 | Handled potential division by zero in `flapContentRevealStart/End` divisor

## [1.9.4] - 2026-06-28
### ✨ 기능
- PageFlipConfig.copyWith() 26개 필드 전수 지원 및 clear-flag로 nullable 필드 초기화 | Added full copyWith() for all 26 fields with clear-flags for nullable fields

### 🐛 수정
- PageFlipConfig.== 연산자에 semanticBuilder 필드 누락되어 잘못된 동등성 비교 | Fixed == operator missing semanticBuilder field causing incorrect equality
- PageFlipStateController.dispose()가 AnimationController.dispose()를 중복 호출하던 버그 (비멱등성 보호) | Fixed dispose() calling AnimationController.dispose() twice (idempotency guard)

### 🧪 테스트
- Phase I-VI 통합 테스트 대규모 추가: 설정 정확성, 상태 컨트롤러 분기, 물리 속성기반 60+개, 위젯 제스처, 양면모드·멀티터치, 기하 불변속성, 메모리 생명주기, 플랫폼 채널, 접근성, 대용량 아이템, 스트레스 | Added comprehensive Phase I-VI tests: 60+ physics property-based, gesture/edge/widget, double-spread/multitouch integration, geometry invariants, memory lifecycle, platform channels, accessibility, large itemCount, stress
- PageFlipConfig 서명, 복사, 스프레드모드 3개 파일 55개 테스트 | Config copyWith, equality, spread mode tests
- 컨트롤러 엣지케이스 30개 및 프로그램 API 검증 | Controller edge case and programmatic API tests
- 위젯 제스처·콜백·엣지탭 통합 30개 테스트 + 5개 기존 파일 개선 | Widget gesture/callback/edge tap tests with 5 existing file enhancements
### 🐛 수정
- 햅틱 물리 계산이 항상 400px로 하드코딩되어 기기 크기에 따라 진동 강도가 달라지던 버그 수정 (실제 뷰포트 폭 사용)
- 페이지를 많이 넘길수록 메모리가 누적되던 PaperPhysicsEngine 맵 무한 성장 버그 수정
- goToPage()가 드래그/애니메이션 중 호출되면 내부 상태 불일치가 발생하던 문제 수정 (guard 추가)
- 햅틱 텍스처 노이즈의 .abs()로 인한 불연속 도함수로 진동 출력에 "딸깍" 느낌이 발생하던 문제 수정

### ⚡ 성능
- 페이지플립 레이어 스냅샷 렌더링에서 불필요한 RepaintBoundary 제거로 GPU compositing layer 오버헤드 감소

### ♻️ 리팩토링
- onHandleEffect의 문자열 기반 enum 매칭(name.contains('Haptic'))을 안전한 switch 문으로 변경
- PageFlipGestureRecognizer에 @Deprecated 마킹 (PageFlipGestureLayer로 대체됨)
- PageFlipEffectHandler 인터페이스에 viewportWidth setter 추가
- shouldRepaint에 누락된 performanceProfile 필드 검사 추가

## [1.9.0] - 2026-06-26
### ✨ 기능
- 외부 `vibration` 라이브러리를 제거하고 고성능 플랫폼 채널 기반 `AdvancedHapticEngine` 신규 구축
- Android (Core Haptics Composition APIs - Click/Tick/Thud) 및 iOS (CoreHaptics - CHHapticEngine) 맞춤형 네이티브 진동 연동
- 드래그 속도에 비례하는 동적 주기 스로틀링(Dynamic Throttling) 및 마찰/강성에 따른 반응성 최적화

## [1.8.1] - 2026-06-25
### 🐛 수정
- 2단보기 페이지플립 settle 단계(progress 0.85-0.95)에서 목적지 대신 현재 페이지 콘텐츠가 표시되던 버그 수정
- EPUB TOC 페이지(epub:type="toc")가 일반 챕터로 분할되어 페이지가 흩어지던 문제 수정

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

## [1.9.3] - 2026-06-27
### 🐛 수정
- 사운드 재생을 `stop()+seek()+resume()` 패턴으로 변경하여 간헐적 재생 실패 해결 (play()의 setSource() asset I/O 제거)
- Android `VIBRATE` 퍼미션 누락으로 햅틱이 전혀 작동하지 않던 버그 수정 (AndroidManifest에 권한 추가)
- 네이티브 플러그인 vibrator 미사용 시 error 반환하도록 수정 (Dart fallback 활성화)

## [1.9.2] - 2026-06-27
### 🐛 수정
- `_playSound`에서 `resume()` 대신 `play()`를 사용하도록 수정 (audioplayers 6.x: `stop()` 후 `resume()`은 no-op)
- `AdvancedHapticEngine.playTransient()` 및 `playThud()`에 `HapticFeedback` 폴백 추가 (MethodChannel 실패 시 기본 진동 보장)

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
