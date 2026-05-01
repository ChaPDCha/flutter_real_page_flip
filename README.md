# Real Page Flip Engine for Flutter

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![License](https://img.shields.io/badge/license-Dual--License-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

A professional, high-fidelity 3D-like page flip engine for Flutter. Specifically engineered to deliver **ultra-smooth 60/120 FPS performance even on low-end devices** through advanced rendering optimizations.

<p align="center">
  <a href="https://github.com/user-attachments/assets/f9b19621-af97-4ffc-b1bb-7626b9e3b99e">
    <img src="https://raw.githubusercontent.com/ChaPDCha/flutter_real_page_flip/main/doc/assets/realpageflip_sample.webp" width="600" alt="Click to play Full Performance Demo">
  </a>
  <br>
  <em>Click the image above to watch the full high-fidelity performance demo (v1.2+)</em>
</p>

[English] | [한국어](#한국어-korean)

## Demos 🎬
* **[▶️ Watch Legacy Interaction Demo (Core Physics & Gestures)](https://github.com/user-attachments/assets/b8337766-993d-4c3d-8255-7b6e92736484)**


## Why Real Page Flip? (The Technical Edge) 🚀

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

## Sensory Experience: Sound and Haptics 🎧

What truly sets this engine apart is the immersive sensory feedback:
- **Physical Sound Effects**: High-quality rustle sounds that vary naturally with your gesture speed.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine.

## Installation 📦

Add `real_page_flip` to your `pubspec.yaml`:

```yaml
dependencies:
  real_page_flip: ^1.2.2
```

## Quick Start 🚀

```dart
import 'package:real_page_flip/real_page_flip.dart';

PageFlipWidget(
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## License 📜

This project uses a **Dual License** model:
- **Non-commercial**: Free for personal/open-source projects.
- **Commercial**: Requires a paid license for revenue-generating products.
See [LICENSE](LICENSE) for details.

---

## 한국어 (Korean)

**Real Page Flip Engine**은 플러터를 위한 고성능 물리 기반 페이지 전환 엔진입니다. 특히 **저사양 기기에서도 끊김 없는 60/120 FPS 성능**을 보장하기 위해 설계된 독보적인 렌더링 최적화 기술이 적용되었습니다.

### 기술적 차별점 (Professional Edge) 🛠️

1. **하이브리드 스냅샷 엔진**: 애니메이션 중 복잡한 위젯 트리를 매 프레임 다시 그리는 대신, 페이지를 고해상도 이미지로 캡처하여 처리합니다. 덕분에 아무리 복잡한 UI라도 GPU 부하 없이 부드럽게 넘어갑니다.
2. **지능형 메모리 윈도잉**: 수만 장의 페이지가 있어도 현재와 앞뒤 페이지, 단 3장만 메모리에 유지하여 리소스 낭비를 원천 차단합니다.
3. **제로-오버헤드 지오메트리**: 무거운 3D 변환 대신 정교한 수학적 경로 클리핑(Path Clipping)을 사용하여 깨끗한 종이 휘어짐과 그림자 효과를 구현했습니다.
4. **견고한 레이아웃 설계**: 'Constraint Gate' 구조를 통해 어떤 복잡한 위젯 트리 안에서도 레이아웃 에러 없이 안정적으로 작동합니다.

---

Built with ❤️ by [ChaPDCha](https://github.com/ChaPDCha)
