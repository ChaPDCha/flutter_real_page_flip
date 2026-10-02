# Real Page Flip Engine for Flutter

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![tests](https://img.shields.io/badge/tests-1400%2B%20passing-brightgreen)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![analysis](https://img.shields.io/badge/analyzer-0%20issues-success)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/ChaPDCha)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Live Demo](https://img.shields.io/badge/demo-live%20web%20preview-6C63FF?logo=flutter)](https://chapdcha.github.io/flutter_real_page_flip/)
[![platforms](https://img.shields.io/badge/platforms-6%2F6-blue)](https://pub.dev/packages/real_page_flip)

A production-hardened page flip engine for Flutter. Single-page and double-spread.
Physics-based paper fold, adaptive haptics, sound, dark mode. Runs on Android, iOS,
Web (CanvasKit + WASM), Windows, macOS, and Linux — all 6 Flutter platforms.

## Built for RealBible. Running in Production.

Real Page Flip is the rendering engine behind two live Google Play apps:

- [**RealBible**](https://play.google.com/store/apps/details?id=com.jinproduction.realbible&pcampaignid=web_share)
- [**The King's Way (왕의 길)**](https://play.google.com/store/apps/details?id=kr.chapdcha.thekingsway&pcampaignid=web_share)

This is not a weekend prototype. It is the engine that thousands of readers use
every time they turn a page. Every edge case below was encountered on a real
device, reported by a real user, and fixed:

| Real-world issue | Resolved |
|------------------|----------|
| iPhone SE haptic motor buzz | Fixed |
| Dark-paper shadow blade artifacts | Fixed |
| Single-page flap splitting into stacked sheets | Fixed |
| Extreme vertical drag causing layer seams | Fixed |
| GPU memory leak from static shader cache | Fixed |

1,400+ tests. 0 analyzer issues. Free (MIT) for any project, commercial or personal.

**This engine is different because it has already solved edge cases that only
surface after thousands of real-world page turns.**

English | [한국어](README_KR.md)

## What Sets This Engine Apart

- **Real-device verified**: Tested on budget iPhone SE and low-end Android devices — every listed bug was reported by an actual user and fixed.
- **1,400+ tests, 0 analyzer issues**: Covers gesture arbitration, geometry invariants, memory lifecycle, accessibility, and stress scenarios.
- **Tunable performance**: Three rendering profiles (low/medium/high) trade fidelity for speed. Pick one per device tier; the default is medium.
- **Physics-modeled visuals**: Crease shadows, paper curl shading, and dark-paper moonlight tones derived from physical paper behavior.
- **Complete sensory feedback**: Continuous haptic waveform pipeline synchronized with speed-varying page-rustle audio.
- **Production architecture**: small, focused source files with documented structure.

## Demos

### Live Web Preview

**[Try it in your browser →](https://chapdcha.github.io/flutter_real_page_flip/)**

Drag or tap the pages to feel the physics. Switch between single-page and
double-spread mode, tune sensitivity and paper opacity, or toggle haptics
(on a real device) — all from the in-app control deck.

### Mobile single-page view

Four slow page turns on a portrait mobile viewport using the high-quality rendering profile.

![Mobile single-page page flip](doc/screenshots/mobile_single_page_demo.webp)

### 16:9 double-spread view

Four slow spread turns with distinct left- and right-page content, on a 16:9 landscape viewport.

![16:9 double-spread page flip](doc/screenshots/mobile_double_spread_demo.webp)

## Technical Foundation

### Hybrid Snapshot Engine
During a flip, the renderer works from flattened page textures instead of
repainting the full widget tree every frame. Actual frame rate depends on page
capture cost, device, and host layout.

### Intelligent Memory Windowing
Retained page state is bounded around the active page window. Whether your book
has 10 pages or 10,000, memory footprint stays constant.

### Lightweight Geometry Engine
Curved clips, dynamic shadows, and highlights are calculated with a custom
math-based Path Clipping engine — no heavy 3D perspective transforms.

### Production-Hardened Layouts
Internal constraint gate prevents "unbounded height" errors in common `Stack`,
`Column`, and `Scaffold` compositions.

---

## Sensory Experience

- **Sound**: High-quality page-rustle audio that varies naturally with gesture speed.
- **Haptics**: Perceptual gain pipeline with adaptive quality routing. Continuous
  waveform texture on premium devices, discrete confirmation on basic motors.

## Installation

```bash
flutter pub add real_page_flip
```

Requires Flutter 3.44 or newer.

## Platform support

| Platform | Page flip and gestures | Haptics | Default page-turn sound |
|----------|------------------------|---------|-------------------------|
| Android | Yes | Native vibration, with amplitude and composition effects where the motor supports them | Yes (`SoundPool`) |
| iOS | Yes | Native Core Haptics, UIKit feedback as a fallback | Yes (`AVAudioPlayer`) |
| Web (CanvasKit + WASM) | Yes | Flutter's `HapticFeedback`, where the browser supports vibration | Yes (`HTMLAudioElement`) |
| Windows, macOS, Linux | Yes (pure Dart, no native code) | None; calls fall back to Flutter's `HapticFeedback` | None; pass a `PageFlipSoundPlayer` |

## Quick Start

```dart
import 'package:real_page_flip/real_page_flip.dart';

PageFlipWidget(
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## Single-page settle policy

Controls whether the moving back face eases into the destination near the end of
a single-page turn. Disable for a stable back face until the page commits:

```dart
PageFlipWidget(
  config: const PageFlipConfig(
    enableSinglePageSettleReveal: false,
  ),
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

Double-spread mode always maps the physical verso and ignores this setting.

## Snapshot refresh and thermal budget

For long, scrollable, or provider-heavy pages, use dirty-aware refreshing:

```dart
final flipController = PageFlipController();

PageFlipWidget(
  controller: flipController,
  contentRevision: documentRevision,
  config: const PageFlipConfig(
    snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.whenDirty,
    maxSnapshotPixelRatio: 2.25,
  ),
  itemCount: pages.length,
  itemBuilder: (context, index) => pages[index],
)

flipController.markPageDirty(changedPageIndex);
flipController.markCurrentPageDirty(prewarm: false);
```

`whenDirty` observes scrolling and pre-captures after scroll end. Use
`contentRevision` for declarative refresh, or `markPageDirty()` for one page.
`maxSnapshotPixelRatio` caps only the moving raster texture; settled content
remains at native resolution.

## Custom sound

The engine ships one default page-turn sound. Sound is optional, so it is
fully replaceable without touching haptics:

```dart
// Keep the default player, use your own asset (declared in your pubspec).
PageFlipConfig(soundPlayer: DefaultPageFlipSound(asset: 'assets/sounds/flip.mp3'))

// Or bring your own audio backend.
class MyFlipSound implements PageFlipSoundPlayer {
  @override
  Future<void> warmUp() async {/* preload */}

  @override
  Future<void> play({required double volume}) async {/* play */}

  @override
  void dispose() {}
}
```

- `volume` is a velocity-scaled suggestion in `0.0..1.0`.
- `enableSound: false` disables any player; nothing is loaded.
- A player you pass in is yours to dispose — the engine never disposes it.
- The default player loads lazily: apps with sound off, or with a custom
  player, never touch the audio stack.
- The default sound plays on **Android, iOS, and web** through this package's
  own plugin (no third-party audio dependency). **Desktop has no default
  sound**; pass your own player there, for example with `audioplayers`:

```dart
import 'package:audioplayers/audioplayers.dart';

class AudioplayersFlipSound implements PageFlipSoundPlayer {
  final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  @override
  Future<void> warmUp() => _player.setSource(
        AssetSource('packages/real_page_flip/assets/sounds/page_flip.mp3'),
      );

  @override
  Future<void> play({required double volume}) async {
    await _player.stop();
    await _player.setVolume(volume * 0.4);
    await _player.resume();
  }

  @override
  void dispose() => _player.dispose();
}
```

## Flip Sensitivity

Independent forward/backward drag thresholds and gesture sensitivity:

```dart
PageFlipWidget(
  config: PageFlipConfig(
    cutoffForward: 0.35,
    cutoffPrevious: 0.5,
    sensitivity: 0.5,
  ),
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## Accessibility and input

- **Reduce motion**: when the system setting is on (iOS Reduce Motion, Android
  "Remove animations", the browser's `prefers-reduced-motion`), edge taps,
  `nextPage` and `previousPage` change page at once and a released drag snaps
  to its destination. The finger still moves the page directly while dragging.
  Opt out with `PageFlipConfig(respectReducedMotion: false)`.
- **Screen readers**: the book announces "Page N of M" and supports the
  increase, decrease and scroll actions. Change the text with `semanticBuilder`.
- **Keyboard** (opt-in): `PageFlipConfig(enableKeyboardNavigation: true)` turns
  pages with Right/Left arrows, Page Down/Up and Space (Shift+Space goes back);
  Home and End jump to the first and last page.
- **Mouse wheel and trackpad** (opt-in):
  `PageFlipConfig(enableWheelNavigation: true)` turns one page per scroll
  gesture. A scrollable page keeps the wheel until it reaches its end.

Not supported yet: right-to-left reading direction. The engine always turns
pages like a left-to-right book.

## Double-spread (two-page) mode

```dart
PageFlipWidget(
  spreadMode: PageFlipSpreadMode.doubleSpread,
  itemCount: spreadCount,
  itemBuilder: (context, spreadIndex) => MyTwoPageSpread(spreadIndex),
)
```

| Responsibility | Detail |
|----------------|--------|
| `itemBuilder` | Each index renders a full-width spread (left + right pages). |
| `itemCount` | Number of spreads (e.g. `ceil(pageCount / 2)`). |
| Spine reveal | Forward reveals the left half of the next spread; backward the right half of the previous. |

## Foldables, dual-screen devices and window resizing

The engine fills whatever box it is given and adapts to any shape, so it needs
no foldable-specific setup. Folding, unfolding, rotating and entering split
screen all just change that box. When the shape changes by more than about
10% in one step, the page snapshots are recaptured on the very next frame
instead of after a 300 ms wait, so a page turned right after unfolding is
stretched for a frame or two at most. The test suite replays folds, unfolds and
rotations between the display shapes of the Galaxy Z Fold8 and Fold8 Ultra (and
a 4:3 and a 3:4 shape standing in for the iPhone Duo, whose ratio Apple does
not state), in both single-page and double-spread mode. It has not run on the
devices.

**You choose single page or two-page spread.** The engine does not switch by
itself. A shape-based rule works on every platform. A Galaxy Z Fold8 opened
like a book (a 4:3 inner display, folded down the middle) is the natural fit for
a spread, and the iPhone Duo is a book-style foldable too:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    final spread = constraints.maxWidth >= constraints.maxHeight * 1.2;
    return PageFlipWidget(
      spreadMode:
          spread ? PageFlipSpreadMode.doubleSpread : PageFlipSpreadMode.single,
      // Carry the reader's place across the switch: one spread holds two pages.
      itemCount: spread ? (pageCount + 1) ~/ 2 : pageCount,
      initialIndex: spread ? page ~/ 2 : page,
      onPageChanged: (index) => setState(() => page = spread ? index * 2 : index),
      itemBuilder: (context, index) =>
          spread ? MyTwoPageSpread(index) : MyPage(index),
    );
  },
)
```

Switching mode while a page is in the air ends that turn: `onFlipEnd` fires
once, `onPageChanged` does not (the turn was counted in the old numbering), and
the book lands on the `initialIndex` you pass.

**The fold and the hinge.** In double-spread mode the spine is the middle of the
widget, which is where these devices fold when the book fills the display. The
engine itself does not read `MediaQuery.displayFeatures`, and Flutter fills that
list **only on Android**, so on iOS (iPhone Duo) decide from the window shape as
above. On Android, `MediaQuery.displayFeaturesOf(context)` reports a `fold`
(a crease that does not hide pixels, like the Galaxy Z Fold) or a `hinge` (a
gap that hides part of the screen, like a dual-screen device), with the posture
(`postureFlat`, `postureHalfOpened`). If a hinge hides pixels, leave a gutter in
your spread content, or wrap the book in `DisplayFeatureSubScreen` to keep it on
one screen.

**Android manifest.** Keep `orientation|screenSize|smallestScreenSize|screenLayout|density`
in the activity's `android:configChanges` (Flutter's default template does).
Without them Android restarts the activity at every fold, and your app has to
restore the reading position.

## Dark Mode

Theme-aware by default. Shadows, highlights, and edge masks adapt automatically
based on background luminance. Zero config:

```dart
MaterialApp(
  theme: ThemeData.light(),
  darkTheme: ThemeData.dark(),
  themeMode: ThemeMode.system,
  home: Scaffold(
    body: PageFlipWidget(
      itemCount: pages.length,
      itemBuilder: (context, index) => MyPage(index),
    ),
  ),
)
```

## Performance Benchmark

```bash
cd example
flutter run --profile -t lib/performance_benchmark.dart \
  --dart-define=PERFORMANCE_PROFILE=medium \
  --dart-define=FLIPS=80
```

The benchmark runs 80 consecutive page flips on a real device and reports:

| Metric | Target |
|--------|--------|
| Build time (avg) | < 6 ms |
| Raster time (avg) | < 5 ms |
| P90 frame time | < 10 ms |
| P99 frame time | < 12 ms |
| Max frame time | < 18 ms |
| Jank count (80 flips) | 0 |

Run across low/medium/high profiles to validate your target device tier. The
benchmark is designed to catch regressions in snapshot capture, geometry
computation, and shader performance before they reach users.

## Support the Project

Real Page Flip is free (MIT) and always will be. Maintaining a production-grade
engine — running 1,400+ tests, verifying fixes across real devices, and keeping
pace with Flutter releases — requires sustained investment.

[Sponsor on GitHub →](https://github.com/sponsors/ChaPDCha)

For companies, sponsorship tiers include having your name or logo listed here.

## License

MIT — free for any project, commercial or personal. See [LICENSE](LICENSE).

Built by [ChaPDCha](https://github.com/ChaPDCha)
