# Real Page Flip Engine for Flutter

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![Sponsor this project](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/ChaPDCha)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

A high-fidelity, 3D-like page flip engine for Flutter with bounded snapshot
windowing and configurable rendering profiles for a broad range of devices.

## Built for RealBible, Proven in Production

Real Page Flip is the page-flip engine developed for the production of
[RealBible](https://play.google.com/store/apps/details?id=com.jinproduction.realbible&pcampaignid=web_share).
It has since been successfully integrated into and commercialized in both of
the following applications:

- Jinproduction homepage https://sharebible.org/
- [RealBible](https://play.google.com/store/apps/details?id=com.jinproduction.realbible&pcampaignid=web_share)
- [The King's Way (왕의 길)](https://play.google.com/store/apps/details?id=kr.chapdcha.thekingsway&pcampaignid=web_share)

> **Notice**: This page flip engine is fully optimized for both single-page vertical layouts and horizontal two-page view (double-spread mode) for tablets and wider screens.

English | [한국어](README_KR.md)

## Support the Project

If Real Page Flip helps your app, please [buy us a coffee through GitHub
Sponsors](https://github.com/sponsors/ChaPDCha). Monthly sponsorships help fund
maintenance, performance work, and new releases.

For companies, GitHub Sponsors can provide monthly sponsorship tiers with a
custom reward such as having your company name or logo listed in this README.
See the [GitHub Sponsors profile](https://github.com/sponsors/ChaPDCha) for the
currently available tiers and sponsorship terms.

## Demos

### Mobile single-page view

Four slow page turns recorded on a portrait mobile viewport using the high-quality rendering profile.

![Mobile single-page page flip](doc/screenshots/mobile_single_page_demo.webp)

### 16:9 double-spread view

Four slow spread turns with distinct left- and right-page content, recorded on a 16:9 landscape viewport using the high-quality rendering profile.

![16:9 double-spread page flip](doc/screenshots/mobile_double_spread_demo.webp)

## Why Real Page Flip? (The Technical Edge)

Most page flip libraries struggle with performance as UI complexity increases. Real Page Flip is built differently:

### 1. Hybrid Snapshot Engine (GPU Optimization)
Unlike other libraries that attempt to render live widget trees during heavy animations, our engine **captures high-resolution snapshots** of your pages. 
- **The Benefit**: During a flip, the renderer works from flattened page textures (`RawImage`) instead of repainting the complete host widget tree every frame. Actual frame rate still depends on page capture cost, device, and host layout.

### 2. Intelligent Memory Windowing
Whether your book has 10 pages or 10,000, retained page state is bounded around the active page window.
- **The Benefit**: The engine keeps the current and adjacent pages needed for navigation instead of retaining every page widget and snapshot.

### 3. Lightweight Geometry Engine
We avoid heavy 3D perspective transforms that can be jittery on older hardware. Instead, we use a **custom math-based Path Clipping engine**.
- **The Benefit**: Curved clips, dynamic shadows, and highlights are calculated without requiring a full 3D scene.

### 4. Production-Hardened Layouts (Single Constraint Gate)
Ever had a "Vertical viewport was given unbounded height" error? Not here.
- **The Benefit**: The internal constraint gate provides stable bounded sizing in common `Stack`, `Column`, and `Scaffold` compositions.

---

## Sensory Experience: Sound and Haptics

What truly sets this engine apart is the immersive sensory feedback:
- **Physical Sound Effects**: High-quality rustle sounds that vary naturally with your gesture speed.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine.

## Installation

Add `real_page_flip` to your `pubspec.yaml`:

```bash
flutter pub add real_page_flip
```

The default haptic mode is capability-adaptive: premium devices use native
continuous texture and semantic primitives, amplitude-controlled devices use a
stable waveform, and basic motors receive short confirmation feedback only.
Use `PaperTexturePreset.none` for a fully silent haptic mode.

```dart
PageFlipConfig(
  hapticQuality: HapticQuality.adaptive, // recommended
  hapticTexturePreset: PaperTexturePreset.textured,
)
```

## Quick Start

```dart
import 'package:real_page_flip/real_page_flip.dart';

PageFlipWidget(
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## Flip Sensitivity

Control the drag-release threshold for completing page flips in each direction:

```dart
PageFlipWidget(
  config: PageFlipConfig(
    // Forward flip completes when drag exceeds 40 % (default 0.4)
    cutoffForward: 0.35,
    // Backward flip threshold (default 0.4)
    cutoffPrevious: 0.5,
    // Overall gesture sensitivity (0.0 = firm, 1.0 = light touch)
    sensitivity: 0.5,
  ),
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

Higher values require dragging further across the page to complete a flip.
Setting forward/previous independently lets you tune bias (e.g. easier to go
forward than backward).

## Double-spread (two-page) mode

For books that show left and right pages together:

```dart
PageFlipWidget(
  spreadMode: PageFlipSpreadMode.doubleSpread, // or isDoubleSpread: true
  itemCount: spreadCount, // number of spreads, not single pages
  config: PageFlipConfig(
    skipTapAnimation: false, // required to animate spine-band reveal on tap
    flapBackStrength: 0.0, // default: keep mirrored back text disabled
  ),
  itemBuilder: (context, spreadIndex) => MyTwoPageSpread(spreadIndex),
)
```

**Host contract**

| Responsibility | Detail |
|----------------|--------|
| `itemBuilder` | Each index renders a **full-width spread** (left + right pages). |
| `itemCount` | Number of spreads (e.g. `ceil(pageCount / 2)`). |
| Stable builder | Use a method or `const` closure—not a new inline lambda every `build`, or snapshots reset too often. |
| Snapshots | The engine captures `spreadSnapshots[currentIndex ± 1]` when `includeCurrentSpread` is true (flip start, page settle, init). |
| Spine reveal | Forward flip reveals the **left half** of the next spread; backward reveals the **right half** of the previous spread. |

Use `clipSpreadPageHalf` from the engine when aligning host layout with flip layers.

`flapBackStrength` is intentionally disabled by default for reader performance
and text clarity. Set it around `0.3` only when you want the subtle mirrored
through-paper effect in double-spread mode.

## Profile-mode performance benchmark

Run the benchmark entrypoint on a real device in profile mode to measure frame
timing under rapid page turns:

```bash
cd example
flutter run --profile -t lib/performance_benchmark.dart --dart-define=PERFORMANCE_PROFILE=medium --dart-define=DOUBLE_SPREAD=false --dart-define=FLIPS=80
```

Use `DOUBLE_SPREAD=true` to measure two-page spread mode. The benchmark logs
build/raster averages, P90/P99, max frame time, and jank count from
`FrameTiming`.

## Dark Mode Support

The engine is **theme-aware by default**. With `backgroundColor: null` (the
default since v1.3.0), the flipping page automatically uses the host app's
`scaffoldBackgroundColor`, and shadow/highlight intensities are calculated from
the background luminance at paint time.

### Zero-config automatic dark mode

```dart
MaterialApp(
  theme: ThemeData.light(),
  darkTheme: ThemeData.dark(),
  themeMode: ThemeMode.system,
  home: Scaffold(
    body: PageFlipWidget(
      itemCount: pages.length,
      itemBuilder: (context, index) => MyPage(index),
      // No config needed — dark mode just works
    ),
  ),
)
```

### Custom dark paper color

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;

PageFlipWidget(
  config: PageFlipConfig(
    backgroundColor: isDark
        ? const Color(0xFF1A1F3A)  // dark navy
        : const Color(0xFFEEEEEE), // warm paper
  ),
  itemCount: pages.length,
  itemBuilder: (context, index) => MyPage(index),
)
```

### What adapts automatically

| Element | Light mode | Dark mode |
|---------|------------|-----------|
| Paper back color | `scaffoldBackgroundColor` | `scaffoldBackgroundColor` |
| Inner shadow strength | 35 % | 20 % (softer) |
| Fold highlight | 5 % | 18 % (stronger for depth) |
| Edge tap indicator | Dark glow | Light glow |

> **Note**: Page *content* (text, images, backgrounds) is controlled by your
> `itemBuilder`. The engine only manages the flip animation layer.

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details. It is completely free for both non-commercial and commercial projects.

Built by [ChaPDCha](https://github.com/ChaPDCha)
