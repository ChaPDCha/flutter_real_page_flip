# Flutter 실시간 페이지 플립 엔진 (Real Page Flip) 📖✨

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![License](https://img.shields.io/badge/license-듀얼--라이선스-blue.svg)](LICENSE_KR)
[![Flutter](https://img.shields.io/badge/Flutter-SDK-%2302569B?logo=flutter)](https://flutter.dev)

플러터를 위한 전문가용 고성능 3D 스타일 페이지 플립 엔진입니다. 독보적인 렌더링 최적화 기술을 통해 **저사양 기기에서도 안정적인 60/120 FPS 성능**을 제공하도록 설계되었습니다.

<p align="center">
  <a href="https://github.com/ChaPDCha/flutter_real_page_flip">
    <img src="https://raw.githubusercontent.com/ChaPDCha/flutter_real_page_flip/main/doc/assets/realpageflip_sample.webp" width="600" alt="Real Page Flip Demo">
  </a>
</p>

## 왜 Real Page Flip인가요? (기술적 차별점) 🚀

기존의 페이지 플립 라이브러리들은 UI가 복잡해질수록 성능 저하가 발생하기 쉽습니다. Real Page Flip은 근본적으로 다른 접근 방식을 취합니다:

### 1. 하이브리드 스냅샷 엔진 (GPU 부하 최소화)
무거운 애니메이션 중에 매 프레임 위젯 트리를 다시 그리는 방식이 아닙니다. 우리 엔진은 페이지의 고해상도 **스냅샷을 캡처(Flattening)**하여 처리합니다.
- **장점**: 페이지가 아무리 복잡한 텍스트와 이미지로 구성되어 있어도, GPU는 단 하나의 이미지 텍스처(RawImage)만 처리하면 됩니다. 덕분에 저사양 기기에서도 실크처럼 부드러운 모션이 보장됩니다.

### 2. 지능형 메모리 윈도잉 (Intelligent Windowing)
책이 10장이든 10,000장이든 메모리 점유율은 일정하게 유지됩니다.
- **장점**: 현재, 이전, 다음 페이지만 위젯 트리에 유지하고 나머지는 즉시 해제합니다. 기존 `PageView` 기반 라이브러리들에서 흔히 발생하는 메모리 비대화 문제를 완벽히 해결했습니다.

### 3. 제로-오버헤드 지오메트리 엔진
오래된 하드웨어에서 떨림 현상을 유발할 수 있는 무거운 3D 변환 대신, 정교한 **수학적 경로 클리핑(Path Clipping) 엔진**을 사용합니다.
- **장점**: 계산 오버헤드 없이 완벽하고 깨끗한 종이 휘어짐, 동적 그림자, 그리고 빛 반사 효과를 구현합니다.

### 4. 프로덕션 수준의 레이아웃 안정성 (Single Constraint Gate)
"Vertical viewport was given unbounded height" 같은 레이아웃 에러로 고생할 필요가 없습니다.
- **장점**: 내부의 '제약 게이트' 구조가 부모 위젯(Stack, Column, Scaffold 등)이 무엇이든 상관없이 안정적으로 크기를 조정하고 렌더링합니다.

---

## 감각적인 경험: 사운드와 진동 🎧

오감을 자극하는 피드백으로 완성도를 높였습니다:
- **실감 나는 사운드**: 드래그 속도에 따라 자연스럽게 변화하는 고품질 종이 질감 사운드.
- **정밀한 햅틱**: 종이의 마찰력과 마지막에 붙는 느낌을 손끝으로 전달합니다.

## 설치 방법 📦

`pubspec.yaml`에 `real_page_flip`을 추가하세요:

```yaml
dependencies:
  real_page_flip: ^1.2.0
```

## 라이선스 📜

이 프로젝트는 **듀얼 라이선스** 모델로 제공됩니다:
- **비상업적 이용**: 개인 프로젝트, 오픈소스 프로젝트 등에서 무료로 사용 가능.
- **상업적 이용**: 수익이나 상업적 이익이 발생하는 제품(광고 포함 앱 등)은 유료 라이선스가 필요합니다.

상세 내용은 [LICENSE](LICENSE) 및 [LICENSE_KR](LICENSE_KR)를 확인하세요.

---

Built with ❤️ by [ChaPDCha](https://github.com/ChaPDCha)
