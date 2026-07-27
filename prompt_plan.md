# Implementation Plan: Verified Publisher + audioplayers Extraction

## 목표

1. pub.dev verified publisher 등록 (sharebible.org)
2. audioplayers 의존성을 `real_page_flip_audio` 패키지로 분리 → core 6개 플랫폼 지원
3. 버전 릴리스 정책 안정화

---

## Phase 1: pub.dev Verified Publisher (30분, 코드 변경 없음)

sharebible.org 도메인으로 pub.dev verified publisher 등록한다.

### 절차
1. pub.dev → Create Publisher → 도메인 `sharebible.org` 입력
2. pub.dev가 생성한 TXT 레코드 값 확인
3. sharebible.org DNS에 TXT 레코드 추가
4. pub.dev에서 Verify 버튼 클릭
5. 완료되면 pub.dev 패키지 페이지에 "Verified" 배지 + JINPRODUCTION 이름 표시

---

## Phase 2: real_page_flip_audio 패키지 분리 (핵심)

### 현재 구조 분석

**audioplayers를 import하는 파일은 단 1개:**
```
lib/src/widgets/default_page_flip_effect_handler.dart
```

**Platform channel haptics 사용 파일들 (handler를 통해서만 호출됨):**
```
lib/src/models/advanced_haptic_engine.dart     → default handler만 사용
lib/src/physics/continuous_haptic_buffer.dart  → default handler만 사용
```

**Physics pipeline (core에 유지 — PaperPhysicsEngine이 사용):**
```
StickSlipController, PaperPhysicsEngine, PaperPhysicsFrame, PaperPhysicsConfig
```

**Haptic enum/data types (core에 유지 — PageFlipConfig가 참조):**
```
HapticQuality, HapticStrength, PaperTexturePreset, PerceptualHapticGain
```

### 핵심 원칙

> Core(`real_page_flip`)는 순수 Dart/Flutter 렌더링만. 사운드/햅틱은 `real_page_flip_audio`로 분리.

### Step 1: Audio 패키지 scaffolding

```
real_page_flip_audio/
├── pubspec.yaml              # depends: real_page_flip + audioplayers
├── analysis_options.yaml
├── README.md
├── CHANGELOG.md
├── LICENSE
├── lib/
│   └── real_page_flip_audio.dart   # barrel: re-exports DefaultPageFlipEffectHandler
├── android/                  # native haptic plugin (namespace: com.chapdcha.real_page_flip_audio)
├── ios/                      # native haptic plugin
└── assets/
    └── sounds/
        ├── page_flip.mp3
        └── page_flip.opus
```

### Step 2: Core에서 제거, Audio로 이동

| 파일 | 작업 | 비고 |
|------|------|------|
| `lib/src/widgets/default_page_flip_effect_handler.dart` | core→audio 이동 | audioplayers 유일한 consumer |
| `lib/src/models/advanced_haptic_engine.dart` | core→audio 이동 | handler만 호출 |
| `lib/src/physics/continuous_haptic_buffer.dart` | core→audio 이동 | handler만 호출 |
| `android/` | core에서 삭제, audio로 복사 | 네임스페이스: real_page_flip_audio |
| `ios/` | core에서 삭제, audio로 복사 | pod name: real_page_flip_audio |
| `assets/sounds/` | core에서 삭제, audio로 복사 | 사운드 에셋 |

### Step 3: Core pubspec.yaml 변경

```diff
-  audioplayers: ^6.5.1

-  plugin:
-    platforms:
-      android:
-        package: com.chapdcha.real_page_flip
-        pluginClass: RealPageFlipPlugin
-      ios:
-        pluginClass: RealPageFlipPlugin

-  assets:
-    - assets/sounds/page_flip.mp3
-    - assets/sounds/page_flip.opus
```

결과: core는 plugin 선언 없음 → 자동으로 모든 플랫폼(6개) 지원

### Step 4: Core public API 변경

**`lib/real_page_flip.dart`에서 제거:**
```diff
- export 'src/widgets/default_page_flip_effect_handler.dart';
```

**`lib/src/page_flip_widget.dart` 변경:**
```diff
- import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';

+ // DefaultHandler가 없으면 no-op handler 사용
+ // No-op은 내부 정의 (public API 아님)
```

NoOpEffectHandler는 `lib/src/widgets/` 내부 파일로 생성. PageFlipWidget의 `_effectHandler` 초기화에서 fallback으로 사용.

### Step 5: 테스트 정리

| 파일 | 작업 |
|------|------|
| `test/widgets/default_page_flip_effect_handler_test.dart` | core→audio 이동 |
| `test/features/effects/default_page_flip_effect_handler_test.dart` | core→audio 이동 |
| `test/features/effects/haptic_preset_baseline_test.dart` | core→audio 이동 |
| `test/models/advanced_haptic_engine_test.dart` | core→audio 이동 |
| `test/physics/continuous_haptic_buffer_test.dart` | core→audio 이동 |
| `test/utils/test_helpers.dart` | audioplayers mock 제거 |
| `test/page_flip_memory_test.dart` | audioplayers mock import 제거 |
| 그 외 core test들 | DefaultPageFlipEffectHandler 참조 → NoOpEffectHandler로 변경 |

Core: ~1199 → ~1080 tests
Audio: ~120 tests (이동된 파일들)

### Step 6: Example 앱 업데이트

```yaml
# example/pubspec.yaml
dependencies:
  real_page_flip:
    path: ../
  real_page_flip_audio:
    path: ../real_page_flip_audio  # 추가
```

```dart
// example/lib/main.dart
import 'package:real_page_flip_audio/real_page_flip_audio.dart';  // 추가
```

### Step 7: README/CHANGELOG

- README.md: "Audio & Haptics" 섹션 추가, migration 가이드
- CHANGELOG.md: 2.1.0 breaking change 명시
- real_page_flip_audio/README.md: 간단한 usage 가이드

---

## Phase 3: 버전 정책 변경

### 현황
```
v2.0.0 (07-11) → v2.0.16 (07-27) = 16일, 17개 릴리스 ≈ 1개/일
```

### 변경
- 버그 수정은 하루에 하나씩 배포하지 않고 주간 단위로 묶는다
- 2.1.0 이후로는 패치 버전을 최소 3~5일 간격으로
- CHANGELOG에 "왜" 고쳤는지 항상 명시 (이미 잘 되어 있음)

---

## 위험 분석

1. **Breaking change**: `DefaultPageFlipEffectHandler` import가 깨짐
   - 완화: `real_page_flip_audio` 의존성 추가 + import 변경 한 줄이면 해결
   - CHANGELOG와 README에 명확히 안내

2. **Native plugin channel 충돌**: 기존 앱이 `real_page_flip` 플러그인을 캐시하고 있을 경우
   - 완화: `flutter clean` 실행 안내

3. **pub.dev 점수**: Plugin → Package 전환으로 채점 기준 변경
   - 완화: 사전에 `pana`로 점수 확인, 160점 유지 목표

4. **테스트 수 감소**: 1199 → ~1080
   - 완화: audio 패키지가 ~120개 테스트를 그대로 가져감. 전체로 보면 동일

---

## 파일별 변경 요약

| 범주 | 파일 수 | 설명 |
|------|---------|------|
| Core에서 삭제 | ~8 | android/, ios/, assets/sounds/, handler, engine, buffer |
| Core에서 수정 | ~6 | pubspec.yaml, barrel, widget, tests, example |
| Audio에 생성 | ~15 | 패키지 scaffold + 이동된 파일들 + 네이티브 코드 |
| 영향 없는 파일 | ~50+ | 모든 렌더링/지오메트리/물리 엔진 파일 그대로 유지 |
