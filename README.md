# Real Page Flip Engine for Flutter 📖✨

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![License](https://img.shields.io/badge/license-Dual--License-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

A professional, high-fidelity 3D-like page flip engine for Flutter. Engineered for performance, realism, and sensory immersion.

<p align="center">
  <img src="doc/assets/demo.webp" width="400" alt="Real Page Flip Demo">
</p>

## Overview

Welcome! This is a Flutter library designed to give your app a highly realistic, 3D-like page turning effect. We focused on recreating the physical feel of paper, complete with proper shadow rendering, specular highlights, and fluid, natural motion.

Whether you're building a digital magazine, a realistic book reader, or a presentation app, this engine makes the reading experience feel tactile and beautiful.

## Key Features ✨

- **Physics-Based Interaction**: Real-time modeling of paper friction and mechanical resistance during drag.
- **Hardware-Accelerated Rendering**: Custom geometry engine with optimized clipping for smooth 60/120 FPS performance.
- **Tactile Feedback**: Integrated haptic feedback and synchronized sound effects for a truly immersive experience.
- **Single Constraint Gate**: Robust layout handling to prevent "Unbounded Height/Width" errors in complex widget trees.
- **Accessibility**: Full semantics support for screen readers.

## Sensory Experience: Sound and Haptics 🎧

What truly sets this engine apart is the immersive sensory feedback:
- **Physical Sound Effects**: Each flip triggers a high-quality sound effect that mimics the rustle of a real page, varying naturally with the speed of your gesture.
- **Tactile Haptics**: Feel the friction and the "snap" of the paper through your device's haptic engine.
- **Customizable**: Toggle feedback with `PageFlipConfig.enableSound` / `enableHaptics`, or plug in a fully custom `effectHandler`.

## Installation 📦

Add `real_page_flip` to your `pubspec.yaml`:

```yaml
dependencies:
  real_page_flip: ^1.1.1
```

## Quick Start 🚀

```dart
import 'package:flutter/material.dart';
import 'package:real_page_flip/real_page_flip.dart';

class MyBook extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PageFlipWidget(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Container(
          color: Colors.orange[50],
          child: Center(child: Text('Page ${index + 1}')),
        );
      },
    );
  }
}
```

## Technical Documentation 🛠️

- **[Layout Constraints Guide](README_LAYOUT_CONSTRAINTS.md)**: How the engine handles Flutter's layout system.
- **[Contributing Guidelines](CONTRIBUTING.md)**: How to help improve the engine.
- **[Security Policy](SECURITY.md)**: Reporting vulnerabilities.

## License 📜

This project uses a **Dual License** model:

- **Non-commercial (free)**: Personal projects, non-profit apps, academic tools.
- **Commercial (paid)**: Any product that generates revenue or commercial benefit (including ad-supported apps) requires a commercial license.

See [LICENSE](LICENSE) for the full text.

---

## 한국어 (Korean)

**Real Page Flip Engine**은 플러터를 위한 고성능 물리 기반 페이지 전환 엔진입니다. 단순한 2D 변환을 넘어, 실제 종이의 마찰력과 저항감을 수학적으로 모델링하여 최상의 독서 경험을 제공합니다.

### 주요 기능
- **실감나는 물리 모델링**: 드래그 속도와 위치에 따른 종이의 휘어짐과 저항을 실시간 계산합니다.
- **하드웨어 가속 렌더링**: 최적화된 클리핑 기술을 통해 부드러운 애니메이션을 구현합니다.
- **입체적 피드백**: 진동과 사운드 효과를 통해 손끝으로 느껴지는 조작감을 완성했습니다.

한글 라이선스 안내: [LICENSE_KR](LICENSE_KR)

---

Built with ❤️ by [ChaPDCha](https://github.com/ChaPDCha)
