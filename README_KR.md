# Flutter 실시간 페이지 플립 엔진 (Real Page Flip)

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![tests](https://img.shields.io/badge/tests-1199%20passing-brightgreen)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![analysis](https://img.shields.io/badge/analyzer-0%20issues-success)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![후원](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/ChaPDCha)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

실제 서비스에서 검증된 Flutter 페이지 플립 엔진입니다. 단면 보기와 양면 보기를
모두 지원하며, 물리 기반 종이 접힘, 적응형 햅틱, 사운드, 다크 모드를 제공합니다.
저사양 기기에서도 끊김 없이 작동합니다.

## RealBible를 위해 개발되어, 실제 서비스에서 검증됨

Real Page Flip은 현재 Google Play에 출시된 두 개의 앱에서 사용되고 있습니다:

- [**RealBible (리얼바이블)**](https://play.google.com/store/apps/details?id=com.jinproduction.realbible&pcampaignid=web_share)
- [**왕의 길 (The King's Way)**](https://play.google.com/store/apps/details?id=kr.chapdcha.thekingsway&pcampaignid=web_share)

이 엔진은 주말 프로토타입이 아닙니다. 수천 명의 독자가 페이지를 넘길 때마다
사용하는 렌더링 엔진입니다. 아래 모든 엣지 케이스는 실제 기기에서 실제 사용자가
발견하고 수정된 항목들입니다:

| 실제 발생 문제 | 해결 |
|--------------|------|
| iPhone SE 진동 모터 버즈 노이즈 | 수정 완료 |
| 다크 모드에서 그림자 칼날 현상 | 수정 완료 |
| 단면 넘김에서 3겹으로 갈라지는 레이어 | 수정 완료 |
| 극단적 수직 드래그 시 레이어 경계 불일치 | 수정 완료 |
| 정적 셰이더 캐시로 인한 GPU 메모리 누수 | 수정 완료 |

1,199개 테스트. 분석기 0 이슈. MIT 라이선스로 상업적/비상업적 모든 프로젝트에서 무료.

2026년, AI 코딩 도구는 페이지 플립 애니메이션을 몇 분 만에 생성할 수 있습니다.
**이 엔진은 AI가 생성한 프로토타입이 아직 만나보지도 못한 문제들을 이미 해결했다는
점에서 다릅니다.**

[English](README.md) | 한국어

## 생성된 코드가 아닌, 검증된 엔진을 선택해야 하는 이유

| AI가 생성한 프로토타입 | Real Page Flip |
|----------------------|----------------|
| 개발자 폰에서만 작동 | 저가형 iPhone과 Android에서 검증됨 |
| 겉보기에만 정상 | 1,199개 테스트가 보이지 않는 엣지 케이스 방지 |
| 단일 해상도만 대응 | 저/중/고 세 가지 적응형 성능 프로필 |
| 단순한 시각 효과 | 물리 모델 기반 접힘 그림자, 종이 컬 셰이딩, 다크 페이퍼 문라이트 톤 |
| 감각 피드백 없음 | 연속 햅틱 파형 파이프라인 + 페이지 넘김 사운드 동기화 |

## 데모

### 모바일 1면 보기

![모바일 1면 페이지 넘김](doc/screenshots/mobile_single_page_demo.webp)

### 16:9 2면 보기

![16:9 2면 페이지 넘김](doc/screenshots/mobile_double_spread_demo.webp)

## 기술 기반

- **하이브리드 스냅샷 엔진**: 애니메이션 중에는 위젯 트리를 매 프레임 다시
  그리지 않고, 캡처된 페이지 텍스처로 렌더링합니다.
- **지능형 메모리 윈도우**: 10페이지든 10,000페이지든 메모리 점유율은 활성
  페이지 주변으로 제한됩니다.
- **경량 지오메트리 엔진**: 무거운 3D 변환 없이, 수학 기반 Path Clipping
  엔진으로 곡선 클리핑, 동적 그림자, 반사 효과를 계산합니다.
- **프로덕션 레이아웃 안정성**: 내부 제약 게이트가 `Stack`, `Column`,
  `Scaffold` 등 어떤 부모 위젯에서도 안정적인 크기를 보장합니다.

## 감각 경험

- **사운드**: 드래그 속도에 따라 자연스럽게 변화하는 고품질 페이지 넘김음.
- **햅틱**: 기기 성능에 따라 자동 조정되는 햅틱 품질 라우팅. 프리미엄 기기는
  연속 파형 텍스처, 기본 모터는 개별 확인 피드백.

## 설치

```bash
flutter pub add real_page_flip
```

## 빠른 시작

```dart
import 'package:real_page_flip/real_page_flip.dart';

PageFlipWidget(
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## 단면 보기 정착 텍스처 정책

단면 모드에서 페이지가 완료되기 직전 뒷면을 목적지에 맞춰 완화할지 제어합니다:

```dart
PageFlipWidget(
  config: const PageFlipConfig(
    enableSinglePageSettleReveal: false,
  ),
  itemCount: 10,
  itemBuilder: (context, index) => MyPage(index),
)
```

## 스냅샷 갱신

길고 스크롤이 있는 페이지나 Provider 구독이 많은 페이지에서 dirty 기반 갱신 사용:

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
```

## 다크 모드

배경 휘도에 따라 그림자, 하이라이트, 엣지 마스크가 자동으로 조정됩니다.
별도 설정 불필요:

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

## 2면 보기 (Double-Spread)

```dart
PageFlipWidget(
  spreadMode: PageFlipSpreadMode.doubleSpread,
  itemCount: spreadCount,
  itemBuilder: (context, spreadIndex) => MyTwoPageSpread(spreadIndex),
)
```

## 프로젝트 후원

Real Page Flip은 MIT 라이선스로 영원히 무료입니다. 그러나 프로덕션급 엔진 유지 —
1,199개 테스트 실행, 실제 기기 검증, Flutter 업데이트 대응 — 에는 지속적인
투자가 필요합니다.

[GitHub Sponsors에서 후원하기 →](https://github.com/sponsors/ChaPDCha)

기업 후원자는 README에 회사명 또는 로고를 노출하는 맞춤형 리워드를 선택할 수
있습니다.

## 라이선스

MIT — 상업적/비상업적 모든 프로젝트에서 무료. [LICENSE](LICENSE) 참조.

Built by [ChaPDCha](https://github.com/ChaPDCha)
