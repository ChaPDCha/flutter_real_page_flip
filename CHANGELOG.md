# Changelog

All notable changes to the `real_page_flip` **package** will be documented here.
For the example application (Realbook app), see [example/CHANGELOG.md](example/CHANGELOG.md).

## [2.0.5] - 2026-07-14

### Fixed
- **Edge Decorations Detached From the Turning Sheet**: The paper-colour edge/fold masks (which hide crushed mesh texture at the flap boundaries) were painted AFTER the curl shading (bend highlight, cylinder terminator), so the flat paper strip erased the shading across the last few pixels of the sheet. Between the free-edge highlight line and the shaded flap body this left a dark trough on dark paper and a bare bright band on light paper - read as a light line hovering detached from the page edge. The gap widened as the turn progressed (single page) and peaked mid-flip before vanishing near the end (double spread). The masks now paint directly on the content mesh, BEFORE the curl shading and edge highlight, so the curl light/shade runs continuously to the sheet edges and the highlight sits on the paper instead of floating beside it. Verified by pixel probes at phone aspect ratio with tilted drags: the former trough (edge-adjacent luminance dipping below the flap body) is gone in all profiles.

## [2.0.4] - 2026-07-14

### Changed
- **Dark-Paper Flip Accents Read as Moonlight, Not Detached Lines**: On near-black paper the crease valley, binding gutter, stationary-edge band, cylinder curl, and free-edge contact accent were painted pure white -- the gutter and stationary bands additionally with `srcOver`, laying a flat veil over the text beneath. Combined with band widths tuned for dark-on-light shadows, the accents read as crisp bright lines hovering over the page instead of light settling onto it. Dark paper now shares one cool moonlight tone (`0xFFE8E8F0`, the flap-highlight cast) across all lit accents via `discreteShadowTone`, blends them with `screen` so the paper and text brighten optically, widens the discrete bands 1.6x via `glowBandWidthScale` (crease 22->35px, still inside the 36px layout guard; gutter 18/13->29/21px; stationary 14->22px), and drops their peak alphas (double crease 0.08->0.055, single crease 0.07->0.055, gutter 0.09->0.06, stationary 0.06->0.045, ambient 0.02->0.015, free-edge highlight 0.10->0.06). Light-paper rendering is unchanged.

## [2.0.3] - 2026-07-13

### Fixed
- **Single-Page Flap Edge Splitting Into Multiple Layers**: The flap content mesh evaluated vertical curvature over the visible `0..H` range while the screen clip, edge masks, and shadows used the extended `-H..2H` curve domain. Their free edges therefore separated progressively and peaked near mid-flip. The opaque paper underlay also stopped at the flat flap rectangle instead of covering the curved-edge bulge, exposing a narrow wedge of the stationary page. All flap boundaries now share one curve mapping, and the paper coverage bounds include the maximum curve bulge plus seam bleed. Added forward/backward progress-matrix, pixel-edge, all-profile opacity, and refreshed textured golden regressions.

## [2.0.2] - 2026-07-12
### Fixed
- **Double-Spread Flip Shadow Onset and Binding Gutter**: The centre binding shadow snapped on abruptly mid-spread instead of easing in, and appeared as a hard knife-cut line where it met the body text at the spine. Root cause: the crease/gutter/contact shadows scaled directly by `sin(progress·π)` (steep slope at the origin) and the spine "groove" was a single one-sided band clipped hard to the flip half, so its full-alpha edge sat exactly on the spine while the stationary half stayed at zero. Replaced the groove with a symmetric, feathered binding gutter whose two sides share the same peak alpha at the spine (continuous across the binding, no seam), and added an eased onset envelope so the discrete shadows fade in/out over the first/last 14% of the flip. Mid-flip shadow intensity is unchanged. Measured cost: feathering both sides of the spine adds one extra draw call versus the old one-sided groove (double-spread HIGH goes from 31 to 35 canvas operations, 12 to 13 draw calls, per `paint()` call).

### Changed
- **HIGH-Profile 3D Turning Leaf (Double-Spread)**: Deepened the double-spread turning leaf's rounded, lifted appearance on the HIGH performance profile — a reshaped cylinder curl self-shadow (eased 4-stop ramp) so the leaf reads as a rounded tube, a free-edge contact shadow that widens with lift height and gains a soft penumbra so the leaf visibly floats above the spread, and a slightly brighter centre highlight to complete the light→dark roundness contrast. The default MEDIUM profile gets a modest version of the lift-cast shadow at no extra draw cost. Single-page mode and LOW profile are unchanged. No new saveLayers, meshes, blurs, or draw calls — reshapes gradients (extra colour stops, rescaled alpha/width) already being drawn.

## [2.0.1] - 2026-07-11
### Fixed
- **Single-Page Flap Splitting Into Three Sheets**: Mid-to-late flip, the turning page could read as three stacked vertical bands — full-bright stationary page | washed-out flap | crisp revealed page. Root cause: the thin-paper `saveLayer` (default `thinPaperStrength` 0.15) composited the whole single-page flap, opaque paper underlay included, at ~85% alpha, letting the stationary middle layer (the current page, un-mirrored, in its original position) bleed through the sheet. Worst on medium/low performance profiles, whose flap draws no mesh content mid-flip, leaving a naked paper veil over the page beneath. The single-page flap now always renders as one opaque sheet; its thin-paper feel remains conveyed by `singlePageBackContentOpacity` (the flap's own mirrored back-bleed). Double-spread translucency behavior is unchanged. Adds a pixel-probe regression test (half-blue current page) that fails if any middle-layer tint is detectable inside the flap on high or medium profiles.

## [2.0.0] - 2026-07-11
### Added
- Capability-adaptive `HapticQuality` (`adaptive`, `basic`, `standard`, `premium`) with native Android/iOS feature detection and safe quality downgrade.
- `PaperTexturePreset.none` plus clearly separated level 1-4 amplitude, sharpness, grain width, detent, and settle signatures.
- Native Android plugin unit coverage and CI builds for Android and the iOS simulator.

### Changed
- Drag haptics now follow actual finger distance and timestamp-derived speed; basic motors receive semantic confirmation feedback instead of continuous vibration.
- Flip sound now fires only when release commits a page and uses a conservative maximum volume.
- Android plugin and example migrated away from directly applying the legacy Kotlin Gradle Plugin; Gradle/AGP toolchain updated for future Flutter compatibility.
- Publish archive reduced by omitting historical media and generated example shells; README installation and adaptive-haptic guidance refreshed.

### Fixed
- Capability detection now works on Android devices without a vibrator, verifies required primitive support, and starts adaptive mode conservatively until detection completes.
- iOS Swift Package now bundles the privacy manifest, CocoaPods metadata matches the package version, and the stale Android `getPlatformVersion` test now validates the real capability API.
- Single-page curved layer boundaries, contact shadows, and crease masks share one geometric boundary across gesture angles and aspect ratios.

### Breaking
- Adding `PaperTexturePreset.none` requires consumers with exhaustive switches over `PaperTexturePreset` to handle the new case.

## [1.16.1] - 2026-07-11
### Changed
- **Default Thin-Paper Back Bleed**: `singlePageBackContentOpacity` now defaults to `0.35` (was `1.0`) so single-page peels softly dim reverse text like India paper instead of showing crisp front-facing content. Explicit values still override the default; double-spread mode is unchanged.

### Tests
- Updated default-opacity and config coverage to expect the thin-paper bleed overlay; removed redundant explicit `0.35` overrides that now match the default.

## [1.16.0] - 2026-07-10
### Changed
- **True 2.5D Verso Repagination for Double Spreads**: The turning leaf now maps a progress-sized strip from the physically correct adjacent-spread page onto one curved mesh. Forward turns show the next spread's left page from the first lifted pixel through landing; backward turns show the previous spread's right page as the exact mirrored time-reverse.
- **Continuous Opaque Compositing**: Removed the double-spread destination fade gate and the forward-only half-spread middle clip, eliminating the uncovered mid-flip background hole and settle content-swap pop.
- **Lower Per-Frame Cost**: Removed the optional mirrored ghost back mesh and its snapshot lookup, removed one forward middle clip, and retained a single mesh plus existing affine transform, clips, crease/contact shadows, cylinder lighting, and gradients.
- **Compatibility Controls**: `flapBackStrength` and `doubleSpreadMidFoldBleed` remain in the public configuration API but are now no-ops because the real verso is always rendered directly and fully opaque.

### Tests
- Added direction/progress/boundary coverage for verso source strips, pixel-level forward/backward checks at progress 0.3/0.6/0.9 for opaque coverage and correct destination/verso colors, a near-settle continuity threshold at progress 0.97, and four double-spread goldens at progress 0.50/0.85.
- Preserved the single-page rendering path and verified the complete 1,012-test suite, including existing blade and gradient-halo regressions.

## [1.15.2] - 2026-07-10
### Fixed
- **Dark Pillars at Flap Boundaries**: Every gradient in `PageFlipPainter` that faded to `Colors.transparent` (transparent BLACK) painted a semi-opaque dark-gray halo mid-ramp, because Flutter lerps RGB toward black as alpha falls. On light paper this rendered as two hard dark vertical "pillars" hugging the flap's free edge and fold line (measured 25–35% darkening where at most ~15% intended shading exists), and the false lines sat a few pixels inside the real content boundaries — reading as misaligned layer seams. All gradient endpoints now fade to the same hue at alpha 0. Adds a pixel-measuring regression test that renders a flip over plain paper across all performance profiles and fails if any pixel drops below the darkest intended shading.

## [1.15.1] - 2026-07-10
### Changed
- **Analyzer Cleanup**: Fixed 11 pre-existing `flutter analyze` info-level lints (unresolvable Dartdoc `[Name]` references to native Swift/Kotlin types, two intentionally-broad `catch` blocks missing an `on` clause, and `double` literals that should be `int`) that were failing CI on every push. No functional changes.

## [1.15.0] - 2026-07-10
### Added
- **Free-Edge Contact Shadow & Highlight**: The flap's lifted free edge now casts a soft ambient-occlusion shadow onto the page beneath it and catches a thin light highlight, so a mid-flip page reads as physically lifted paper instead of a flat, knife-cut sticker. New `buildCurvedFreeEdgeShadowPath` geometry helper (single- and double-spread).
- **Cylinder Curl Lighting (HIGH profile)**: A terminator-shading gradient across the flap surface makes the curling paper read as a rounded cylinder rather than a flat tilting board. Gated to the HIGH performance profile only — no cost added on low/medium-tier devices.
- **Detent Confirmation Haptic**: A small, crisp micro-tick fires the instant a drag first crosses the success cutoff (`cutoffForward` / `cutoffPrevious`), giving tactile confirmation that releasing now will commit the flip — before the finger ever leaves the screen. One-shot per drag; does not re-fire if the finger wiggles back across the threshold.
- **Sharpness-Aware Haptic Pipeline**: Physics-derived `sharpness` now flows end-to-end (physics frame → `ContinuousHapticBuffer` → native platform channel), so fast flicks feel crisp and slow drags feel soft instead of a fixed native sharpness value.

### Changed
- **Unified Fold-Crease Shadow**: The crease previously stacked two independent dark bands (flap-side darkening + revealed-side drop shadow) that visually merged into one thick, hard-edged line. These are now a single soft valley — narrower, eased gradient stops, and a flap-side band sized to only cover where the curl highlight fades through.
- **Continuous Haptic No Longer Starves on Slow Drags**: Replaced the `_smoothedSpeed > 0.12` emission gate (which silenced the friction texture on slow crawls) with a 0.02 floor and lighter velocity smoothing, plus a smooth sqrt-based speed-to-intensity curve.
- **iOS/Android Persistent Haptic Players**: Native continuous-waveform playback no longer stops and recreates the player every ~40ms flush. iOS streams intensity/sharpness onto one long-lived `CHHapticAdvancedPatternPlayer` via dynamic parameters; Android no longer calls `vibrator.cancel()` before each waveform, since a fresh `vibrate()` already supersedes the running effect. Removes the audible/tactile gap at every batch boundary. *(Native runtime behavior pending physical-device verification — not exercisable from this development environment.)*

### Fixed
- **Bright-Blade Regression on Extreme Angled Drags**: Narrowing the flap-side crease darkening initially uncovered a bright sliver from the existing curl highlight at steep touch angles in double-spread portrait layouts; the highlight's fade-out region and the crease darkening width are now aligned so the crease reads as one continuous valley at every angle.
- **Snap-Back Flicker**: A drag released below the flip cutoff (or cancelled mid-gesture, e.g. yielding to vertical scroll content) used to reset the flip state on the same frame the snap-back animation started, tearing the flip layer down instantly instead of easing it back. The snap-back now defers state reset until the animation completes, and uses a higher minimum duration (180ms vs. the old 80ms floor) so small aborted drags visibly ease back like real paper instead of vanishing in a flicker.

## [1.14.2] - 2026-07-10
### Fixed
- **Flutter 3.44+ Compatibility**: Replaced removed `RenderObject.needsPaint` with direct `toImageSync` call in snapshot refresh path (`pre_render_manager.dart`).
- **Boundary Lifecycle Guard**: Added `boundary.attached` check in `refreshIndexSync` to prevent crashes when `RenderRepaintBoundary` is detached before snapshot capture.

## [1.14.0] - 2026-07-09
### Added
- **Continuous Haptic Waveform Pipeline**: Replaced the discrete haptic transient model with a continuous amplitude-modulated waveform pipeline for natural paper-friction vibration.
  - `StickSlipController`: Redesigned from discrete events (`StickSlipEvent`) to continuous modulation (`StickSlipModulation`), with `amplitudeBoost` (0–0.5) and `sharpnessShift` (–0.3 to +0.3) that blend into every physics frame.
  - `ContinuousHapticBuffer`: New accumulator that samples per-frame intensity and flushes every ~40ms (25Hz) as amplitude arrays to the native platform — no more interrupted tick streams.
  - Android: Uses `VibrationEffect.createWaveform(timings, amplitudes, -1)` for API 26+ continuous vibration.
  - iOS: Uses `CHHapticParameterCurve` with `CHHapticAdvancedPatternPlayer` for real-time intensity modulation.
- **Single Unified Noise Source**: Removed the controller's multi-sine noise generator. The physics engine's Perlin noise is now the only texture source, eliminating dual-noise conflict.

### Changed
- **Stick-Slip Energy Blending**: Stick energy is always blended into the continuous amplitude output so the caller's tick stream is never interrupted by discrete events.
- **Fold Progress Routing**: Controller now passes fold progress (not noise signal) as `foldAngle` to the physics engine.

### Fixed
- **Bright Blade Crescent Artifact**: Increased fold crease shadow intensity from 0.04 to 0.055 to fully mask the geometric bright-blade artifact at curved fold boundaries.
- **Stick-Slip Test Determinism**: Fixed test clock dependency in stationary energy build-up test by adding deterministic fake clock.

## [1.13.0] - 2026-07-09
### Changed
- **Haptic Density Overhaul**: Increased paper-scratch haptic frequency from ~14Hz to ~40-60Hz by removing the 3-frame event skip in `PageFlipStateController` and lowering throttle thresholds across controller, handler, and Android native layers.
  - Controller: Removed `_hapticFrameCounter % 3 == 0` gate — every drag frame now triggers haptic evaluation.
  - Controller: Lowered speed threshold from 0.5 to 0.12 for texture feedback on slow, deliberate drags.
  - Handler: `_minPaperTickGapMs` reduced from 48ms to 20ms, adaptive base throttle (medium profile) from 45ms to 24ms, clamp range from [25,120] to [14,80].
  - Android native: `minVibrateGapMs` reduced from 28ms to 16ms.
- **Performance Impact**: Zero increase in CPU load — the noise calculation already ran every frame. Only the event dispatch rate increased. Native-side throttle still prevents hardware overload.
### Fixed
- **Curved Flap Boundary Shadows**: Replaced straight rectangular edge/fold masks and fold darkening with curved boundary paths so the visible shadow and paper-mask edges follow the same curl geometry as the folded page mesh.

### Tests
- Added regression coverage for free-edge curve math, curved boundary strip masks, path-based edge/fold fade rendering, and refreshed single-page reveal goldens for the corrected curved boundaries.

## [1.12.13] - 2026-07-07
### Added
- **Haptic Diagnostic Sweep**: Added an example-only sweep mode for measuring preset routing and cache invalidation with `--dart-define=RPF_HAPTIC_DIAGNOSTIC_SWEEP=true`.

### Changed
- **Unified Haptic Presets**: Consolidated paper texture preset tuning into `PaperPhysicsConfig`, giving each preset explicit physics, amplitude, sharpness, and duration behavior.
- **Duration-Aware Native Routing**: Threaded calculated haptic duration through Dart, Android, and iOS transient calls so short ticks and longer pulses can route differently per platform.

### Fixed
- **Preset Cache Invalidation**: Changing haptic presets now clears cached per-page physics engines so mid-session preset changes take effect immediately.
- **Android Preset Differentiation**: Smooth paper now remains under the Android primitive-tick threshold, while standard, textured, and kraft route through one-shot pulses with progressively stronger amplitude.

## [1.12.12] - 2026-07-07
### Changed
- **Crease Shadow Refinement**: Softened fold crease shadow opacity by 50% (light mode: 0.16 -> 0.08, dark mode: 0.06 -> 0.03) and narrowed gradient spread stop to 30% to prevent thick, dark lines.

### Fixed
- **Curved Page Edge Boundary**: Corrected the reverse/previous-page flip's free edge boundary mask in `buildFlapScreenClipPath` to use a matching `quadraticBezierTo` curve instead of a straight line, aligning the clip edge to the curled page layout.

## [1.12.11] - 2026-07-06
### Added
- **Slip Burst & Settle Thud**: Added native platform haptic playbacks on Android/iOS for page release slippage and heavy settle thuds.
- **Logarithmic Tactile Scaling**: Implemented Weber-Fechner Law gamma correction for slow drags, magnifying subtle friction textures.

### Changed
- **Adaptive Settle Durations**: Fold animation speed scales dynamically based on release gesture velocity (80ms to 450ms).
- **Neutral Color Temperature**: Refined dark-mode highlights (0xFFE8E8F0) to eliminate glassy blue sheen on OLED screens.

### Fixed
- **Extreme Gesture Artifacts**: Aligned all painter and clipper guards to a shared `kFlipProgressEpsilon` to prevent frame gaps, and raised minimum mesh width to 12px.
- **Dark Mode Shading**: Replaced multiply-black with screen-white for fold creases on dark paper to ensure depth visibility.
- **Low Profile saveLayer Bypass**: Suppressed translucency layers entirely on low performance profiles, saving 2-3ms per frame.

## [1.12.9] - 2026-07-05
### Added
- **High-DPI Support**: Edge and fold masks automatically widen by 25% on high-DPI displays (≥ 2.0) to prevent sub-pixel rendering artifacts and anti-aliasing bleeds.

### Changed
- **Texture Refining**: Clamped thin paper visibility threshold from 0.2 down to 0.05, allowing lighter translucent pages for subtle effects without disappearing.

### Fixed
- **Gesture Reliability**: Added rigorous checks for detached `RenderBox` instances during tap position mapping, preventing rare lifecycle crashes.
- **Config Hashing**: Optimized `PageFlipConfig` equality checks to use `Object.hashAll()`.

## [1.12.8] - 2026-07-05
### Added
- **clipSpreadPageHalf utility**: Exported `clipSpreadPageHalf` helper function for host applications to align local layout calculations with double-spread page boundaries.

### Fixed
- **Stationary Page Shadow**: Resolved extreme vertical drag misalignment in double-spread mode by replacing the axis-aligned `clipRect` with a fold-aligned, normal-projected `clipPath` for the stationary shadow.
- **Angle Clamping**: Tightened the shared fold-angle limit conservatively across shadows, clipping paths, flap meshes, and double-spread layers to prevent edge-corner clipping on extreme aspect ratios.
- **Haptics**: Resolved conflicts between sound fallback playbacks and native textured vibration composition.

## [1.12.7] - 2026-07-04
### Fixed
- Paper-like haptic feedback: replace stick-slip THUD bursts with short TICK textures, debounce native vibration calls, and cancel residual motor output on drag end.
- Reduce drag haptic frequency and intensity ranges to avoid springy, stuttering vibration on Android.

## [1.12.6] - 2026-07-04
### Added
- Dynamic depth rendering: Switches from shadows to reflective highlights on dark background paper (`isPaperDark == true`) for superior visual contrast and depth.
- Double-spread ambient depth: Strengthened stationary edge shadow and spine groove with automated srcOver blending fallback when drawing glowing highlights on dark paper.

### Changed
- Flap Curvature Shading: Strengthened matte highlight sheen (~2x peak) and deepened fold crease darkening with a broader gradient stop (0.55) for a smoother 3D bend.
- Revealed-Page Drop Shadow: Doubled peak alpha and widened drop shadow falloff (36px). Introduced a secondary soft ambient band (1.6x width) for high/medium performance profiles.

## [1.12.5] - 2026-07-03
### Fixed
- Clamped offscreen drag positions before flip geometry reaches layer clippers and painters, keeping extreme vertical swipes on a stable viewport-bound fold angle.
- Extended flap paper, mask, fade, and shadow paint bounds only on angled folds so the screen-space flap clip cannot expose gaps at the top or bottom of the viewport.
- Kept zero-angle horizontal drag rendering visually unchanged while protecting angled drags from clipped shadows and layer seams.

### Tests
- Added extreme vertical drag regression coverage for viewport seam overlap, angled flap paint bounds, viewport touch clamping, and host-app LTR/RTL text-direction scenarios across phone, tablet, desktop, and rotated aspect ratios.

## [1.12.4] - 2026-07-03
### Performance
- Reduced hidden page-flip rendering work by using indexed flap meshes and skipping low-value double-spread mesh draws on low and medium performance profiles outside the settle phase.

### Fixed
- Hardened `PageFlipLayerView` to require a finite viewport size, removing hidden zero-size and infinite-size paint fallback paths.
- Removed unused flap destination mapping from the painter/render pipeline to avoid dead API surface and misleading test coverage.
- Kept unsafe texture gating out of the layer view, so omitted sizing cannot silently suppress flap textures.

### Tests
- Added regression coverage for `skipEarlyMesh`, settle-phase rendering, mesh edge cases, viewport size contracts, painter behavior, and visual goldens.

## [1.12.3] - 2026-07-02
### Fixed
- Removed release/profile `debugNeedsPaint` calls from snapshot refresh paths to prevent `LateInitializationError` crashes during page flips.
- Changed the revealed-page shadow from a straight rectangular band to a curved fold-aligned path, matching the paper edge curve instead of fighting it visually.
- Reduced revealed and stationary shadow weight so the fold reads as thinner, softer paper instead of a heavy slab.

### Tests
- Added curved fold shadow band regression coverage and updated single-page reveal goldens for the softer curved shadow.

## [1.12.2] - 2026-06-30
### Performance
- Changed the default reader profile from `high` to `medium` to reduce mesh density and high-DPI snapshot cost while preserving the full page flip effect.
- Changed the default `flapBackStrength` from `0.3` to `0.0`; double-spread mirrored back text is now opt-in instead of a default GPU cost.
- Skips double-spread back mesh generation entirely when `flapBackStrength <= 0.005` instead of drawing it and covering it with paper.
- Avoids redundant `pageSnapshots` clones in double-spread capture paths; spread snapshots remain available for front, settle, and revealed-page textures.
- Aligns the example app with the new lightweight `medium` default profile and adds a profile-mode `FrameTiming` benchmark entrypoint for rapid page-turn measurement.

## [1.12.1] - 2026-06-30
### 🔧 기하학 및 렌더링 엔진 개선 (Geometry & Rendering Engine Enhancements)
- **Angle Clamping & limits**: 터치 입력 범위를 뷰포트 내로 클램핑하여 과회전을 방지하고, 각도 제한 공식을 `atan2`에서 `asin` 투영법으로 변경하여 더 정확한 물리 한계 구현 | Clamped vertical touch inputs to viewport and updated the angle limit calculation to use `asin` projection, physically preventing flap corners from clipping outside.
- **Normal-aligned bleed**: 단순 가로축(X) 이동 대신 접힘 법선 벡터 `foldNormal` 방향으로 클립 overlap bleed 및 그림자 오프셋을 적용하여, 회전된 각도에서도 그림자와 클립라인이 완전히 일치하도록 정합성 개선 | Shifted clip bleed and shadow offsets along the fold normal vector `foldNormal` instead of raw X-axis, keeping tilted shadow lines parallel.
- **Double-spread shadow fixes**: 양면 이전장(Double-spread backward) 플립 시의 spine 그림자 방향 및 stationary 그림자 좌표가 뒤집히던 버그 해결 | Fixed spine shadow directions and stationary shadow coordinate offsets during double-spread backward flips.

## [1.12.0] - 2026-06-30
### ✨ 단면(Single-page) 모드 대폭 개선 (Single-Page Flip Overhaul)
- **Backward geometry**: 단면 이전장 전환을 양면(spine) 지오메트리 대신 다음장과 동일한 접힘 방향의 **시간 역재생**으로 처리하여 단면 리더에 맞는 자연스러운 넘김 제공 | Single-page backward flips now reuse the forward fold geometry (time-reversed) instead of double-spread spine geometry.
- **Adjacent reveal**: 단면 모드에서 넘김 중 다음/이전 장 콘텐츠가 접힘 뒤에서 연속적으로 보이도록 bottom 레이어 페이드 제거 | Bottom revealed page no longer fades in single-page mode, keeping the destination page visible throughout the flip.
- **Scroll carry-over**: 드래그 시작 시 스크롤 오프셋을 스냅샷에 반영하여 세로 스크롤 후 가로 스와이프 시 같은 읽기 위치 유지 | Scroll offset is captured into flip snapshots so horizontal swipes preserve vertical scroll depth.
- **Thin-paper bleed-through**: `PageFlipConfig.singlePageBackContentOpacity` 옵션 추가 (기본 1.0). 1.0 미만이면 접히는 면의 뒷글씨가 종이색 오버레이로 희미하게 비쳐 보이도록 지원 | New opt-in `singlePageBackContentOpacity` dims peeled back content for thin-paper bleed-through; default preserves existing crisp behaviour.
- **Settle flicker fix**: 비침 오버레이가 정착(settle) 경계에서 한 프레임에 사라지던 깜박임을 `singlePageBackDim` 연속 보간으로 수정 | Bleed overlay now eases out continuously across the settle window instead of snapping off at `isSettlePhase`.

### 🎨 시각 품질 (Visual Quality)
- **Shadow seam**: 접힘 레이어 그림자 밴드 사이 밝은 칼날형 틈새(blade gap) 제거 | Eliminated bright blade-like gaps between shadow bands near the fold.
- **Edge masks**: 다크/라이트 종이에 맞춰 edge·fold 마스크 폭·불투명도를 테마 인식(`isPaperDark`)으로 조정 | Theme-aware edge and fold masks (narrower/softer on dark paper).
- **Highlight sheen**: 다크 종이는 은은한 쿨 톤, 라이트 종이는 따뜻한 매트 하이라이트 | Per-theme matte centre highlights (cool ambient on dark, warm on light paper).
- **Fold crease**: 접힘 끝 테두리 선 두께·강도 완화로 만화적 아웃라인 제거 | Reduced cartoonish fold-edge stroke weight.

### 🧪 테스트 (Tests)
- 단면 backward 역재생, 비침 오버레이, 다크 마스크, 하이라이트 테마, 정착 깜박임 회귀 등 904개 테스트 통과 | Added regression tests for single backward, bleed-through, theme masks, settle flicker; full suite green.

## [1.11.9] - 2026-07-01
### ✨ 데모 애니메이션 세그먼트 최적화 (Demo Animation Segment)
- **Highlight Focus**: README 미리보기 영상의 애니메이션 타임라인을 6초~14초 구간으로 집중 조정하여 페이지 플립의 핵심 물리 엔진 효과를 더 선명하게 강조 | Refined the demo animation segment to showcase the 6s-14s highlight section for better preview.

## [1.11.8] - 2026-06-30
### ✨ 데모 및 애니메이션 시각화 업데이트 (Demo & Visualization)
- **Preview Update**: README 내 데모 애니메이션을 업데이트하여 실제 적용된 햅틱 반응과 물리 엔진의 타이밍을 시각적으로 더 명확하게 반영 | Updated preview animations to better reflect natural haptic and physics timing visually in README.

## [1.11.7] - 2026-06-29
### 🐛 데모 자동재생 버그 및 시뮬레이션 환경 최적화 (Demo Autoplay & Simulation Fix)
- **Autoplay Bug Fix**: 프로그래밍 방식의 드래그 애니메이션이 터치 제스처로 오인되어 오토플레이를 중단시키던 버그 완벽 해결 | Fixed a bug where programmatic drag animations were misinterpreted as touch gestures, incorrectly halting the autoplay sequence.
- **Aspect Ratio Restoration**: 1단 레이아웃은 스마트폰 세로 비율(420x800)로, 2단 레이아웃은 태블릿 가로 비율(1000x650)로 고정하여 실제 기기 사용 환경을 완벽히 시뮬레이션 | Enforced device-centric aspect ratios for the demo viewport, accurately simulating portrait phones for 1-column and landscape tablets for 2-column views.
- **Fast Startup**: 앱 로딩 직후 불필요하게 멈춰있던 대기 시간(3초)을 0.5초로 제거하고 다크 모드 배경을 일치시켜 빈 흰 화면을 없앰 | Eliminated unnecessary white-screen idle time by reducing initial startup delay and matching the index.html background color to the app theme.

## [1.11.6] - 2026-06-29
### ✨ 데모 업데이트 및 UX 개선 (Demo & UX Improvements)
- **Demo Update**: 웹 미리보기 데모가 AnimationController를 사용하여 자연스럽고 몰입감 넘치는 인간적인 드래그 물리 효과를 시뮬레이션하도록 개선 | The web preview demo now simulates fluid human-like page drag physics using an AnimationController, delivering a much more natural and immersive feel.
- **UX Improvement**: 대화형 웹 미리보기에서 기기 프레임, 테두리, 그라데이션 배경을 제거하여 깔끔한 풀스크린 뷰 환경 제공 | Removed device frames, borders, and gradient backgrounds from the Interactive Web Preview for a clean, fullscreen viewing experience.
- **Doc Optimization**: README 데모 섹션을 간소화하여 1단 및 2단 레이아웃 모두를 위한 통합 `Interactive Web Preview` 제공 | Simplified README demo sections to provide a unified `Interactive Web Preview` for both 1-column and 2-column layouts.

## [1.11.5] - 2026-06-29
### ✨ 데모 및 애니메이션 최적화 (Demo & Animation Optimization)
- 패키지 예시 영상(page_flip_demo.webp)이 1-Column 및 2-Column 페이지 플립 애니메이션을 실제로 보여주도록 올바르게 교체 | Replaced the package demo video (page_flip_demo.webp) to properly show the actual 1-Column and 2-Column page flip animations.
- 예제 앱 시작 시의 autoplay 시퀀스 속도를 2배로 빠르게 조정하여 개발자가 효과를 신속하게 확인할 수 있도록 개선 | Shortened and accelerated the example app autoplay sequence so developers can observe the page flip transitions much faster on launch.

## [1.11.4] - 2026-06-29
### 🔧 빌드/배포
- Gradle standalone 빌드 호환성 개선 및 Dart analyzer 경고 해결 | Improved Gradle standalone build compatibility and resolved Dart analyzer warnings

### 🧪 테스트
- 클립 정렬, 플랩 프론트 텍스처, 플립 커브 테스트의 린트 경고(불필요한 접근/형변환/괄호) 수정 | Fixed lint warnings in clip alignment, flap front texture, and flip curve tests

## [1.11.3] - 2026-06-28
### ✨ 예제 레이아웃 개선 및 직관적인 데모 에셋 제공 (Example App & Demo Assets Overhaul)
- 복잡한 대시보드 대신 페이지플립 효과(1단 단면 및 2단 양면)가 한눈에 보이도록 기본 화면을 풀스크린 책 뷰어로 개선 | Redesigned the example app to show a clean, fullscreen book view by default so developers can focus directly on the page flip effects.
- 대시보드를 숨김/표시할 수 있는 토글 옵션을 상단 툴바에 제공 | Added a layout toolbar at the top allowing developers to switch between 1-Column and 2-Column views and toggle the advanced Tuning Deck overlay.
- 시작 시 자동으로 1단 및 2단 넘김 시뮬레이션을 연속 실행해 주는 autoplay/presentation 모드 도입 | Implemented a startup autoplay demonstration sequence that showcases single-page and double-spread animations smoothly.
- 새로운 레이아웃 기준의 고화질 데모 영상 및 스크린샷 에셋을 README와 패키지에 통합 배포 | Generated and packaged clean, dashboard-free animation WebP videos and layout screenshots.

## [1.11.2] - 2026-06-28
### ✨ 문서화 및 데모 에셋 최적화 (Documentation & Demo Assets)
- 대화형 Web 애플리케이션 데모 시뮬레이션을 녹화한 신규 페이지 넘김 애니메이션 비디오(`page_flip_demo.webp`)를 포함한 최신 WebP 포맷 미디어 에셋 제공 | Added a high-fidelity interaction demo video (`page_flip_demo.webp`) showcasing full-cycle page flip animations and the Control Deck live.
- 양면 보기(Double-Spread) 모드 완벽 지원 안내 및 신규 인터랙티브 데모 미디어를 README.md 문서에 통합 반영 | Integrated double-spread support notices and the new web interactive preview into the root README.md.

## [1.11.1] - 2026-06-28
### ✨ 예제 애플리케이션 개선 (Example Application)
- 다크 모드, 네온 컬러 그라데이션, Glassmorphic 패널을 도입하여 개발자 친화적인 프리미엄 톤앤매너로 예제 앱 디자인을 전면 개편 | Completely redesigned the example app with a premium developer-focused look using dark theme, glassmorphic panels, and neon gradients.
- 실시간 모니터링 상태바(페이지수, 엔진 상태 등) 및 PageFlipConfig 파라미터(민감도, 불투명도, AMO 성능 레벨 등)를 즉석에서 튜닝할 수 있는 대화형 Control Deck 탑재 | Implemented an interactive Control Deck with sliders, segmented selectors, and toggles to dynamically test and profile page flip settings live.

## [1.11.0] - 2026-06-28
### ✨ 성능 최적화 (Performance)
- 저사양 기기 최적화를 위한 `PerformanceProfile` 도입 및 매쉬 렌더링 동적 건너뛰기 최적화 | Introduced `PerformanceProfile` and dynamic mesh-rendering skip to optimize GPU performance for low-end devices.
- `PerformanceProfile.low` 모드일 때 시각적으로 변화가 적은 구간(드래그 초기나 넘김 애니메이션 초중반)에서 복잡한 Mesh 연산을 완전히 건너뛰고 단순 텍스처로 대체하여 렌더링 리소스를 절감 | Added `skipEarlyMesh` to bypass complex Mesh rendering during the invisible initial/middle phases of animations on low-profile devices.
- 라이브 페이지 폴백(Live page fallback)이 Double-spread 모드에도 제거되도록 하여, 무거운 위젯 트리가 중복 렌더링될 때 발생하는 GlobalKey 충돌 및 불필요한 리소스 낭비 방지 | Fixed duplicate GlobalKey crashes by removing live page fallback from double-spread OffscreenPreRenderer.

### 🧪 테스트 (Tests)
- 최적화된 렌더링 분기에 맞추어 레이어 뷰 테스트들이 라이브 페이지 대신 Opaque Paper Fallback을 검증하도록 개선 | Updated layer view tests to assert Opaque Paper fallback correctly, reflecting the removed live page fallback optimization.

## [1.10.0] - 2026-06-28
### 🧪 테스트 및 안정성 검증 (Test & Stability)
- 단면 모드(Single Backward) 지오메트리 엣지 케이스 테스트 추가 및 구버전 테스트 로직 최신화 | Added geometry edge case tests and updated outdated test expectations for single backward flips.
- PageFlipClipper와 PageFlipOpenClipper 간의 클리핑 패스 교차점 정합성 및 화면 비율별 오차 없는 완전한 일치 검증 테스트 추가 | Added rigorous clip path alignment tests across multiple aspect ratios to ensure perfect boundary intersections.
- 연속적인 드래그 및 애니메이션 취소 시 발생하는 Race Condition 방지 위젯 통합 테스트 추가 | Added widget integration tests to verify robust handling of rapid, continuous drag and cancellation race conditions.

## [1.9.9] - 2026-06-28
### 🐛 수정
- 뒤집히는 페이지의 그림자 영역(`Revealed Page Shadow`)이 직선 `clipRect` 대신 실제 곡선 폴드 경로(`clipPath`)를 따라 잘리도록 개선하여 모든 화면 비율에서 두 번째 레이어의 곡선 경계선과 그림자가 완전히 일치하도록 수정 | Replaced straight `clipRect` with curved `clipPath` for Revealed Page Shadow, ensuring perfect alignment between the curved fold line boundary and the shadow on all screen aspect ratios

## [1.9.8] - 2026-06-28
### 🐛 수정
- 단면 모드 이전장(Backward) 전환 시 접히는 종이의 잘리는 면적과 그림자 방향이 꼬이던 지오메트리 계산 오류 수정 | Fixed Single Backward flip geometry where flap direction and material width calculations were inverted
- 백그라운드 인접 페이지들이 `Offstage` 설정으로 인해 플러터 엔진에서 페인팅이 생략되어 스냅샷(toImage) 캡처에 영구 실패하던 문제 수정 | Fixed background adjacent page snapshots failing to capture due to `Offstage` omitting painting
- 화면 밖 백그라운드 렌더링 영역의 스크린 리더(Semantics), 포커스(Focus Scope), 마우스/터치 입력(IgnorePointer) 누수를 원천 차단하는 `OffscreenPreRenderer` 도입 | Introduced `OffscreenPreRenderer` to prevent focus, semantics, and pointer interaction leaks from off-screen pre-rendered pages

## [1.9.7] - 2026-06-28
### 🐛 수정
- `onMethodCall()` 전체 try-catch 적용으로 SecurityException 등 모든 예외가 `result.error()`로 전달되어 Dart HapticFeedback fallback이 안정적으로 발동 | Wrapped `onMethodCall()` in try-catch so all exceptions (including SecurityException) propagate as `result.error()`, ensuring reliable Dart HapticFeedback fallback
- `playFallback()`의 `vibrator?.vibrate()` 호출 예외가 상위로 전파되던 문제 수정 | Guarded `vibrator?.vibrate()` in `playFallback()` so exceptions don't bubble up unhandled

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
