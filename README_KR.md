# Flutter 실시간 페이지 플립 엔진 (Real Page Flip)

[![pub package](https://img.shields.io/pub/v/real_page_flip.svg)](https://pub.dev/packages/real_page_flip)
[![tests](https://img.shields.io/badge/tests-1266%20passing-brightgreen)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![analysis](https://img.shields.io/badge/analyzer-0%20issues-success)](https://github.com/ChaPDCha/flutter_real_page_flip)
[![후원](https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=githubsponsors&logoColor=white)](https://github.com/sponsors/ChaPDCha)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Live Demo](https://img.shields.io/badge/demo-라이브%20웹%20미리보기-6C63FF?logo=flutter)](https://chapdcha.github.io/flutter_real_page_flip/)
[![platforms](https://img.shields.io/badge/platforms-6%2F6-blue)](https://pub.dev/packages/real_page_flip)

실제 서비스에서 검증된 Flutter 페이지 플립 엔진입니다. 단면 보기와 양면 보기를
모두 지원하며, 물리 기반 종이 접힘, 적응형 햅틱, 사운드, 다크 모드를 제공합니다.
Android, iOS, Web (CanvasKit + WASM), Windows, macOS, Linux — Flutter 6개 플랫폼
전부에서 저사양 기기까지 끊김 없이 작동합니다.

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

1,227개 테스트. 분석기 0 이슈. MIT 라이선스로 상업적/비상업적 모든 프로젝트에서 무료.

**이 엔진은 수천 번의 실제 페이지 넘김에서만 드러나는 엣지 케이스를
이미 해결했다는 점에서 다릅니다.**

[English](README.md) | 한국어

## 이 엔진의 차별점

- **실제 기기 검증**: 저가형 iPhone SE와 보급형 Android 기기에서 테스트 — 아래 모든 버그는 실제 사용자가 신고하고 수정한 항목입니다.
- **1,227개 테스트, 0 analyzer 이슈**: 제스처 중재, 기하학 불변속성, 메모리 생명주기, 접근성, 스트레스 시나리오까지 포괄.
- **적응형 성능**: 저/중/고 세 가지 렌더링 프로필이 기기 성능에 자동으로 맞춰집니다.
- **물리 기반 비주얼**: 실제 종이 동작에서 유도된 접힘 그림자, 종이 컬 셰이딩, 다크 페이퍼 문라이트 톤.
- **완전한 감각 피드백**: 속도에 따라 변화하는 페이지 넘김 사운드와 연속 햅틱 파형 파이프라인이 동기화됩니다.
- **프로덕션 아키텍처**: 문서화된 구조의 31개 집중형 소스 파일.

## 데모

### 라이브 웹 미리보기

**[브라우저에서 직접 체험하기 →](https://chapdcha.github.io/flutter_real_page_flip/)**

페이지를 드래그하거나 탭하여 물리 엔진을 직접 느껴보세요. 단면/양면 보기 전환,
민감도 및 종이 불투명도 조절, 햅틱 토글(실제 기기에서)까지 인앱 컨트롤 덱에서
모두 조작할 수 있습니다.

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

Flutter 3.44 이상이 필요합니다.

## 플랫폼 지원

| 플랫폼 | 페이지 넘김·제스처 | 햅틱 | 기본 페이지 넘김 소리 |
|--------|--------------------|------|------------------------|
| Android | 지원 | 네이티브 진동 (모터가 지원하면 진폭·컴포지션 효과) | 지원 (`SoundPool`) |
| iOS | 지원 | 네이티브 Core Haptics, 실패 시 UIKit 피드백 | 지원 (`AVAudioPlayer`) |
| Web (CanvasKit + WASM) | 지원 | 브라우저가 진동을 지원하면 Flutter `HapticFeedback` | 지원 (`HTMLAudioElement`) |
| Windows, macOS, Linux | 지원 (순수 Dart, 네이티브 코드 없음) | 없음 (Flutter `HapticFeedback`으로 폴백) | 없음 — `PageFlipSoundPlayer`를 직접 전달 |

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

## 사운드 커스터마이즈

엔진에는 기본 페이지 넘김음 하나가 들어 있습니다. 사운드는 부가 기능이라
햅틱은 그대로 두고 사운드만 교체할 수 있습니다.

```dart
// 기본 플레이어에 앱의 음원만 교체 (pubspec에 asset 선언 필요)
PageFlipConfig(soundPlayer: DefaultPageFlipSound(asset: 'assets/sounds/flip.mp3'))

// 또는 원하는 오디오 백엔드로 직접 구현
class MyFlipSound implements PageFlipSoundPlayer {
  @override
  Future<void> warmUp() async {/* 미리 로드 */}

  @override
  Future<void> play({required double volume}) async {/* 재생 */}

  @override
  void dispose() {}
}
```

- `volume`은 넘기는 속도에 따라 조절된 `0.0..1.0` 권장값입니다.
- `enableSound: false`면 어떤 플레이어도 로드·재생하지 않습니다.
- 직접 넘긴 플레이어의 dispose는 앱이 책임집니다. 엔진은 dispose하지 않습니다.
- 기본 플레이어는 처음 쓸 때 로드됩니다. 사운드를 끄거나 커스텀 플레이어를
  쓰면 오디오 기능을 아예 건드리지 않습니다.
- 기본 음향은 이 패키지의 자체 플러그인으로 **Android, iOS, 웹**에서
  재생됩니다(외부 오디오 의존성 없음). **데스크톱에는 기본 음향이 없습니다.**
  필요하면 `audioplayers` 등으로 `PageFlipSoundPlayer`를 직접 구현해 넘기세요
  (예제는 영문 README의 Custom sound 참고).

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

## 성능 벤치마크

```bash
cd example
flutter run --profile -t lib/performance_benchmark.dart \
  --dart-define=PERFORMANCE_PROFILE=medium \
  --dart-define=FLIPS=80
```

실제 기기에서 80회 연속 페이지 넘김을 실행하고 다음을 측정합니다:

| 측정 항목 | 목표 |
|-----------|------|
| Build time (평균) | < 6 ms |
| Raster time (평균) | < 5 ms |
| P90 프레임 시간 | < 10 ms |
| P99 프레임 시간 | < 12 ms |
| 최대 프레임 시간 | < 18 ms |
| Jank 횟수 (80회) | 0 |

저/중/고 프로필에서 각각 실행하여 대상 기기 티어를 검증하세요. 스냅샷 캡처,
지오메트리 연산, 셰이더 성능의 회귀를 사용자 도달 전에 감지할 수 있습니다.

## 프로젝트 후원

Real Page Flip은 MIT 라이선스로 영원히 무료입니다. 그러나 프로덕션급 엔진 유지 —
1,227개 테스트 실행, 실제 기기 검증, Flutter 업데이트 대응 — 에는 지속적인
투자가 필요합니다.

[GitHub Sponsors에서 후원하기 →](https://github.com/sponsors/ChaPDCha)

기업 후원자는 README에 회사명 또는 로고를 노출하는 맞춤형 리워드를 선택할 수
있습니다.

## 라이선스

MIT — 상업적/비상업적 모든 프로젝트에서 무료. [LICENSE](LICENSE) 참조.

Built by [ChaPDCha](https://github.com/ChaPDCha)
