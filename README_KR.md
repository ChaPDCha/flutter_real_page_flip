<video src="https://github.com/user-attachments/assets/656892d5-a426-4161-9630-511447a1b347" controls="controls" style="max-width: 100%;"></video>

Flutter 실시간 페이지 플립 엔진

안녕하세요! 이 라이브러리는 Flutter 앱에 굉장히 현실적이고 3D 느낌이 나는 페이지 넘김 효과를 구현해 주는 엔진입니다. 실제 종이를 넘길 때의 물리적인 느낌을 살리기 위해 그림자 표현, 빛 반사 효과, 그리고 물 흐르듯 자연스러운 모션을 구현하는 데 많은 공을 들였습니다.

디지털 매거진, 실제 책과 같은 느낌의 리더 앱, 또는 특별한 프레젠테이션을 만들고 계신다면, 이 엔진을 통해 사용자에게 훨씬 더 시각적이고 감각적인 읽기 경험을 제공할 수 있습니다.

이 라이브러리를 만든 이유

기존의 Flutter 페이지 플립 효과들은 대부분 단순한 2D 변환에 의존해서 실제 종이의 느낌을 제대로 살리지 못하는 경우가 많았습니다. 그래서 이 엔진을 직접 개발하게 되었습니다.

지원하는 모든 기기에서 부드러운 60FPS를 유지하도록 구조를 짰습니다. 사용자의 터치 제스처를 정밀하게 추적하고 스와이프하는 속도에 맞춰 페이지가 자연스럽게 넘어가도록 만들어서, 스마트폰 화면에서도 진짜 종이를 다루는 것 같은 착각을 불러일으킵니다.

안정성과 성능

보이지 않는 디테일과 안정성도 놓치지 않았습니다. 보통 동적인 위젯이나 화면 크기가 변하는 환경에서 페이지 플립을 구현하면 레이아웃 에러가 나거나 앱이 뻗는 경우가 종종 발생합니다.

하지만 이 엔진은 뷰포트가 커질 때 흔히 발생하는 무한 레이아웃 제약(unbounded layout constraint) 에러를 원천적으로 차단하도록 설계되었습니다. 상태를 가진 복잡한 위젯들을 넘길 때도 완전히 안전하고 예측 가능하게 동작합니다. 코드로 화면 전환을 제어할 때도 실행 중인 애니메이션이 안전하게 끝날 때까지 상태 전환을 대기하도록 만들어서, 매우 안정적으로 화면을 조작할 수 있습니다.

위젯에서 제약이 어떻게 보장되는지는 [README_LAYOUT_CONSTRAINTS.md](README_LAYOUT_CONSTRAINTS.md)를 참고하세요.

감각적인 경험: 사운드와 진동

이 엔진의 진짜 특별한 점은 바로 오감을 자극하는 피드백에 있습니다. 시각적인 사실감을 완성하기 위해, 페이지를 넘길 때의 소리와 진동 피드백을 정밀하게 결합했습니다.

- **실감 나는 사운드**: 페이지를 넘길 때 실제 종이가 스치는 듯한 고품질 입체 사운드가 재생됩니다. 넘기는 속도에 따라 소리의 강약이 자연스럽게 변하여 몰입감을 더해줍니다.
- **촉각 피드백(Haptics)**: 종이의 저항감과 마지막에 붙는 느낌을 디바이스의 햅틱으로 전달합니다.
- **커스터마이징**: 패키지에 기본 `page_flip.mp3`가 포함되어 있습니다. `PageFlipConfig.enableSound` / `enableHaptics`로 끌 수 있고, `PageFlipWidget.onHandleEffect`로 이벤트를 가로채거나, `PageFlipConfig.effectHandler`로 핸들러 전체를 교체할 수 있습니다.

설치

요구 사항: Flutter **3.10.0** 이상(`pubspec.yaml` 기준).

앱의 `pubspec.yaml`에 추가합니다:

```yaml
dependencies:
  real_page_flip: ^1.1.1
```

Git 의존성 예시:

```yaml
dependencies:
  real_page_flip:
    git:
      url: https://github.com/ChaPDCha/flutter_real_page_flip.git
      ref: main
```

빠른 시작

```dart
import 'package:flutter/material.dart';
import 'package:real_page_flip/page_flip.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key});

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  final PageFlipController _controller = PageFlipController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageFlipWidget(
        controller: _controller,
        itemCount: 3,
        config: const PageFlipConfig(
          enableSound: true,
          enableHaptics: true,
        ),
        itemBuilder: (context, index) {
          return Center(child: Text('Page ${index + 1}'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _controller.nextPage(),
        child: const Icon(Icons.navigate_next),
      ),
    );
  }
}
```

프로그래밍 방식 제어

`PageFlipWidget`와 함께 `PageFlipController`를 사용합니다.

- `nextPage()` / `previousPage()`는 페이지 플립 애니메이션을 실행합니다(`PageFlipConfig.skipTapAnimation`이면 탭 플립은 즉시 전환될 수 있음).
- `goToPage(index)`는 **애니메이션 없이** 해당 인덱스로 **즉시 이동**합니다(`PageFlipWidget` 구현 기준).

사운드·햅틱·커스텀 효과

- 기본 on/off: `PageFlipConfig(enableSound: false)` 또는 `enableHaptics: false`.
- 이벤트 단위 후킹: `PageFlipWidget(onHandleEffect: (event, {pageIndex, intensity, volume, texture, resistance, timestampMs}) { ... })` — 콜백을 넣으면 해당 효과는 기본 핸들러가 처리하지 않습니다.
- 전체 교체: `PageFlipEffectHandler`를 구현해 `PageFlipConfig(effectHandler: MyHandler())`로 넘깁니다.

레이아웃 제약

스크롤뷰 안에 넣는 등 특수한 부모 아래에 두는 경우 [README_LAYOUT_CONSTRAINTS.md](README_LAYOUT_CONSTRAINTS.md)와 상세 가이드 [doc/flutter_layout_constraints_guide.md](doc/flutter_layout_constraints_guide.md)를 읽어 주세요.

라이선스

이 프로젝트는 **듀얼 라이선스**입니다.

- **비상업적 이용(무료)**: 개인 프로젝트, 비영리 앱, 학술 목적 등 — [LICENSE](LICENSE)(영문) 조건에 따라 사용·수정·배포할 수 있습니다.
- **상업적 이용(유료)**: **수익 또는 상업적 이익**이 발생하는 제품·서비스에 사용하는 경우(유료 앱, 인앱 결제, **광고 수익** 앱, 고객에게 과금되는 사내 도구·B2B 서비스, SaaS 등)에는 사용 전 저작권자와 **상업용 라이선스**를 체결해야 합니다. 세부 조항은 [LICENSE](LICENSE)를 확인하세요.

한글 요약·안내: [LICENSE_KR](LICENSE_KR).

상업용 라이선스나 기타 문의는 이슈 또는 저장소 운영자에게 연락해 주세요.
