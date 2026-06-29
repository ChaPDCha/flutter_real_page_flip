# Real Page Flip Engine for Flutter

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

A professional, high-fidelity 3D-like page flip engine for Flutter. Specifically engineered to deliver **ultra-smooth 60/120 FPS performance even on low-end devices** through advanced rendering optimizations.

> **Notice**: This page flip engine is fully optimized for both single-page vertical layouts and horizontal two-page view (double-spread mode) for tablets and wider screens.

English | [한국어](#한국어-korean)

## Demos

### 1. Interactive Web Preview (Recorded Animation)
This demo showcases the ultra-smooth page flip animations in both **1-Column Layout** and **2-Column Double-Spread Layout**.
![Interactive Web Preview](doc/screenshots/page_flip_demo_v1.11.8.webp)

## Why Real Page Flip? (The Technical Edge)

Most page flip libraries struggle with performance as UI complexity increases. Real Page Flip is built differently:

### 1. Hybrid Snapshot Engine (GPU Optimization)
Unlike other libraries that attempt to render live widget trees during heavy animations, our engine **captures high-resolution snapshots** of your pages. 
- **The Benefit**: During a flip, the GPU only handles a single flattened texture (RawImage) instead of hundreds of nested widgets. This guarantees silky-smooth motion even with extremely complex page layouts.

### 2. Intelligent Memory Windowing
Whether your book has 10 pages or 10,000, the memory footprint remains constant.
- **The Benefit**: We only maintain the current, previous, and next pages in the widget tree. This prevents the "Memory Bloat" common in standard PageView-based implementations.

### 3. Zero-Overhead Geometry Engine
We avoid heavy 3D perspective transforms that can be jittery on older hardware. Instead, we use a **custom math-based Path Clipping engine**.
- **The Benefit**: Perfectly clean curls, dynamic shadows, and specular highlights with minimal computational overhead.

### 4. Production-Hardened Layouts (Single Constraint Gate)
Ever had a "Vertical viewport was given unbounded height" error? Not here.
- **The Benefit**: Our internal "Constraint Gate" ensures the engine works perfectly inside any parent—be it a Stack, Column, or Scaffold—without manual size adjustments.

---

## Sensory Experience: Sound and Haptics

What truly sets this engine apart is the immersive sensory feedback:
- **Physical Sound Effects**: High-quality rustle sounds that vary naturally with your gesture speed.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine.

## Installation

Add `real_page_flip` to your `pubspec.yaml`:

```yaml
dependencies:
  real_page_flip: ^1.4.0
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

---

## 한국어 (Korean)

**Real Page Flip Engine**은 플러터를 위한 고성능 물리 기반 페이지 전환 엔진입니다. 특히 **저사양 기기에서도 끊김 없는 60/120 FPS 성능**을 보장하기 위해 설계된 독보적인 렌더링 최적화 기술이 적용되었습니다.

> **안내**: 이 페이지 플립 엔진은 세로형 단일 페이지 레이아웃과 태블릿 및 넓은 화면을 위한 **가로형 2단 보기(양쪽 페이지 스프레드 모드)**를 모두 완벽하게 지원하도록 최적화되었습니다.

### 데모 시연
이 데모는 **1단 레이아웃**과 **2단 스프레드 레이아웃** 모두에서 매끄러운 페이지 전환 애니메이션을 보여줍니다.
![Interactive Web Preview](doc/screenshots/page_flip_demo_v1.11.8.webp)

### 기술적 차별점 (Professional Edge)

1. **하이브리드 스냅샷 엔진**: 애니메이션 중 복잡한 위젯 트리를 매 프레임 다시 그리는 대신, 페이지를 고해상도 이미지로 캡처하여 처리합니다. 덕분에 아무리 복잡한 UI라도 GPU 부하 없이 부드럽게 넘어갑니다.
2. **지능형 메모리 윈도잉**: 수만 장의 페이지가 있어도 현재와 앞뒤 페이지, 단 3장만 메모리에 유지하여 리소스 낭비를 원천 차단합니다.
3. **제로-오버헤드 지오메트리**: 무거운 3D 변환 대신 정교한 수학적 경로 클리핑(Path Clipping)을 사용하여 깨끗한 종이 휘어짐과 그림자 효과를 구현했습니다.
4. **견고한 레이아웃 설계**: 'Constraint Gate' 구조를 통해 어떤 복잡한 위젯 트리 안에서도 레이아웃 에러 없이 안정적으로 작동합니다.

---

Built by [ChaPDCha](https://github.com/ChaPDCha)
