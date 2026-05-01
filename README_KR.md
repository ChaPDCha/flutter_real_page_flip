# Flutter 실시간 페이지 플립 엔진 (Real Page Flip) 📖✨

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![License](https://img.shields.io/badge/license-듀얼--라이선스-blue.svg)](LICENSE_KR)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

플러터를 위한 전문가용 고성능 3D 스타일 페이지 플립 엔진입니다. 성능, 사실감, 그리고 감각적인 몰입감을 위해 설계되었습니다.

<p align="center">
  <img src="doc/assets/demo.webp" width="400" alt="Real Page Flip Demo">
</p>

## 개요

안녕하세요! 이 라이브러리는 Flutter 앱에 굉장히 현실적이고 3D 느낌이 나는 페이지 넘김 효과를 구현해 주는 엔진입니다. 실제 종이를 넘길 때의 물리적인 느낌을 살리기 위해 그림자 표현, 빛 반사 효과, 그리고 물 흐르듯 자연스러운 모션을 구현하는 데 많은 공을 들였습니다.

디지털 매거진, 실제 책과 같은 느낌의 리더 앱, 또는 특별한 프레젠테이션을 만들고 계신다면, 이 엔진을 통해 사용자에게 훨씬 더 시각적이고 감각적인 읽기 경험을 제공할 수 있습니다.

## 주요 기능 ✨

- **물리 기반 인터랙션**: 드래그 시 종이의 마찰력과 기계적 저항을 실시간으로 모델링합니다.
- **하드웨어 가속 렌더링**: 최적화된 클리핑 기술이 적용된 커스텀 지오메트리 엔진으로 60/120 FPS의 부드러운 성능을 보장합니다.
- **감각적인 피드백**: 페이지를 넘길 때의 소리와 정밀한 진동(Haptics) 피드백이 동기화되어 몰입감을 더해줍니다.
- **Single Constraint Gate**: 복잡한 위젯 트리에서도 "제한 없는 높이/너비(Unbounded)" 에러를 방지하는 견고한 레이아웃 처리를 제공합니다.
- **접근성 지원**: 스크린 리더를 위한 전체 Semantics를 지원합니다.

## 감각적인 경험: 사운드와 진동 🎧

이 엔진의 진짜 특별한 점은 바로 오감을 자극하는 피드백에 있습니다:
- **실감 나는 사운드**: 페이지를 넘길 때 실제 종이가 스치는 듯한 고품질 사운드가 재생됩니다. 넘기는 속도에 따라 소리의 강약이 자연스럽게 변합니다.
- **촉각 피드백(Haptics)**: 종이의 저항감과 마지막에 붙는 느낌을 디바이스의 햅틱 엔진으로 전달합니다.
- **커스터마이징**: `PageFlipConfig.enableSound` / `enableHaptics`로 설정을 제어하거나, `effectHandler`를 통해 완전히 새로운 효과를 적용할 수 있습니다.

## 설치 방법 📦

`pubspec.yaml`에 `real_page_flip`을 추가하세요:

```yaml
dependencies:
  real_page_flip: ^1.1.1
```

## 빠른 시작 🚀

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

## 상세 문서 🛠️

- **[레이아웃 가이드](README_LAYOUT_CONSTRAINTS.md)**: 엔진의 레이아웃 시스템 처리 방식.
- **[기여 가이드](CONTRIBUTING.md)**: 프로젝트 기여 방법.
- **[보안 정책](SECURITY.md)**: 보안 취약점 보고 방법.

## 라이선스 📜

이 프로젝트는 **듀얼 라이선스** 모델로 제공됩니다:

- **비상업적 이용(무료)**: 개인 프로젝트, 비영리 앱, 학술 목적.
- **상업적 이용(유료)**: 수익이나 상업적 이익이 발생하는 모든 제품(광고 포함 앱 등)은 별도의 상업용 라이선스가 필요합니다.

상세 내용은 [LICENSE](LICENSE) 및 [LICENSE_KR](LICENSE_KR)를 확인하세요.

---

Built with ❤️ by [ChaPDCha](https://github.com/ChaPDCha)
