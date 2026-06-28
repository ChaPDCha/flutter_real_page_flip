# PLAN: World-Class Test Coverage for `real_page_flip`

> 목표: 95% line coverage, 90% branch coverage, 모든 사용자 흐름 통합테스트, 메모리 누수 제로 증명

## 요약

| 지표 | 현재 | Phase I | Phase II | Phase III | Phase IV | Phase V | Phase VI |
|------|------|---------|----------|-----------|----------|---------|----------|
| Line Coverage | ~68% | ~73% | ~78% | ~83% | ~88% | ~92% | **~95%** |
| Branch Coverage | ~55% | ~62% | ~70% | ~78% | ~84% | ~88% | **~90%** |
| Test Files | 37 | 39 | 41 | 43 | 45 | 46 | 47 |
| Test Cases | ~380 | ~420 | ~470 | ~530 | ~590 | ~650 | **~680** |

## Phase I: Foundation — 설정 정확성 + 중복 제거

**목표**: `PageFlipConfig` 26개 필드 전수 검증, 중복 테스트 파일 정리. **프로덕션 코드 0 라인 수정**.

**예상 작업량**: 3개 파일 수정, 1개 생성, 3개 삭제 / ~200라인 추가 / PR #1

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/models/page_flip_config_test.dart` | 수정 | equality 18개 + hashCode + defaultSettings ⇒ 20개 케이스 추가 |
| `test/models/page_flip_config_copywith_test.dart` | 생성 | copyWith 26개 필드 전수 + null 전환 ⇒ 28개 케이스 |
| `test/models/page_flip_spread_mode_test.dart` | 수정 | 2→12개: enum 값, isDoubleSpread, fromIsDoubleSpread, 위젯 바인딩 |
| `test/physics_test.dart` | **삭제** | physics/paper_physics_config\* + paper_physics_frame\* 로 대체 (diff 검증 후) |
| `test/effects/clip_alignment_test.dart` | **삭제** | page_flip_clip_alignment_test.dart 로 대체 (diff 검증 후) |
| `test/features/effects/default_page_flip_effect_handler_test.dart` | **삭제** | widgets/default_page_flip_effect_handler_test.dart 로 대체 (diff 검증 후) |

**인수 조건**:
- [ ] `PageFlipConfig.==`: 26/26 필드 inequality 검증 완료
- [ ] `PageFlipConfig.copyWith`: 26/26 필드 전수 검증 완료
- [ ] 삭제 파일 0개 coverage 손실 (diff 검증 필수)
- [ ] 기존 37개 파일 변경 없이 전원 통과
- [ ] `flutter test` clean

**위험**: LOW — 순수 Dart 단위테스트, 위젯 펌핑/플랫폼 채널 불필요

---

## Phase II: 상태 컨트롤러 — 분기 커버리지 + 엣지케이스

**목표**: `PageFlipStateController` branch coverage 65% → 90%. 조건부 분기(속도, 재진입, dispose 중) 전수 검증.

**예상 작업량**: 2개 파일 수정 / ~150라인 추가 / PR #2

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/controllers/page_flip_state_controller_test.dart` | 수정 | 22개 케이스 추가 |
| `test/controllers/page_flip_controller_test.dart` | 수정 | 8개 케이스 추가 |

**핵심 추가 케이스**:
- `onDragStart` when `animationController.isAnimating` → early return
- `onDragEnd` with `isFastFlip=true` (velocity > 300) → skip cutoff check
- `triggerTapFlip` when `isDragging` / `isAnimating` / `isPendingFinalize` → early return
- `triggerTapFlip` at boundary (first/last page) → no-op
- `dispose` idempotent: 두 번 호출해도 throw 없음
- `beginPointerCapture` / `endPointerCapture` re-entrance guard
- `updateCachedWidth` with zero/negative → ignored
- `progressFromHorizontalDelta` with `cachedWidth=0` → returns 0.0
- `goToPage` re-entrance during drag/animation/pending finalize

**인수 조건**:
- [ ] `PageFlipStateController` branch coverage > 88%
- [ ] 속도 분기: velocity=0, 300, 1000, 10000 각각 검증
- [ ] 재진입 방어: 모든 guard 경로 최소 1개 테스트
- [ ] Dispose 안전성: 드래그 중/애니메이션 중/pending 중/이중 dispose

**위험**: LOW-MEDIUM — 일부는 `TickerProvider` 필요(testWidgets)

---

## Phase III: 물리엔진 심화 + 위젯 경계동작

**목표**: 물리엔진 속성기반 테스트 도입, 성능 프로필별 렌더링 경로 검증, 극단적 itemCount 처리.

**예상 작업량**: 4개 수정, 1개 생성 / ~250라인 추가 / PR #3

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/physics/paper_resistance_model_test.dart` | 수정 | 속성기반 12개: 전범위 sweep, 단조성, 경계 |
| `test/physics/stick_slip_controller_test.dart` | 수정 | factory 생성자, 에너지 누적, 가속도 분기 8개 |
| `test/widgets/edge_tap_feedback_test.dart` | 수정 | 다크테마, cancel path, Semantics 6개 |
| `test/page_flip_widget_test.dart` | 수정 | itemCount=0/1/2, isRightSwipe, 경계 8개 |
| `test/page_flip_performance_profile_test.dart` | **생성** | DevicePerformanceProfile 3개 경로 전수 |

**핵심 추가 케이스**:
- `resistance()`가 100개 랜덤 foldAngle에 대해 [0,1] 유지
- `frictionCoefficient()`: velocity=0 → muStatic, 고속 → muKinetic
- `hapticDuration()`: minDurationMs/maxDurationMs 클램핑
- `PaperPhysicsEngine` dispose → 내부 타이머/리소스 해제
- `StickSlipEvent.slipRelease` / `microSlip` / `none` factory 검증
- 성능 프로필 low: 8 segments, 1 column, 단순 그림자
- 성능 프로필 high: 16 segments, 4 columns, 그라디언트 그림자
- `itemCount=1`: 모든 방향 차단, SizedBox.shrink() 없음
- `itemCount=0`: SizedBox.shrink() 렌더링
- `isRightSwipe: true`: 스와이프 방향 반전

**인수 조건**:
- [ ] `PaperResistanceModel` line coverage > 95%
- [ ] `StickSlipController` line coverage > 90%
- [ ] 성능 프로필 3개 전부 painter/mesh 출력 검증
- [ ] `itemCount=0/1/2` 에서 위젯 충돌 없음

**위험**: MEDIUM — 성능 프로필 테스트는 `ui.Image` 생성 필요 (PictureRecorder)

---

## Phase IV: 양면모드 통합 + 멀티터치 + 콜백 검증

**목표**: 가장 큰 커버리지 갭 해소. 양면모드(spreadMode=doubleSpread) 전체 생애주기, 멀티터치 제스처 중재, 모든 콜백 정확성 검증.

**예상 작업량**: 2개 수정, 2개 생성 / ~300라인 추가 / PR #4

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/page_flip_double_spread_integration_test.dart` | **생성** | 양면모드 전 생애주기 15개 |
| `test/page_flip_multitouch_test.dart` | **생성** | 멀티터치 중재 10개 |
| `test/page_flip_callback_test.dart` | 수정 | 양면모드 콜백, effect handler 6개 |
| `test/widgets/page_flip_gesture_layer_test.dart` | 수정 | 활성 포인터 추적, 축 정렬 델타 6개 |

**핵심 추가 케이스**:
- 양면모드: forward flip → `onPageChanged(1)` exactly once
- 양면모드: backward flip → `onPageChanged(0)` exactly once
- 양면모드: full lifecycle (drag start → update → end → animate → finalize → callback) 8단계 검증
- 양면모드: cutoff 미만 snap-back → page change 없음
- 양면모드: `triggerTapFlip` + `goToPage` 동작
- 양면모드: 연속 3회 flip 500ms 내 → index 일관성 유지
- 멀티터치: 두 번째 포인터 down/move/up → 무시
- 멀티터치: 첫 포인터 cancel → 상태 리셋, 두 번째 포인터 가능
- 멀티터치: 동시 다운 → first-mover 승리
- `onFlipStart`: drag progress 적용 전에 호출
- `onFlipEnd`: finalize 후 (index 이미 변경) 호출
- `onHandleEffect`: custom handler override 검증

**인수 조건**:
- [ ] 양면모드: 4개 콜백 전부 정확한 값/횟수로 호출
- [ ] 멀티터치: 두 번째 포인터 항상 거부, 첫 포인터 cancel 시 리셋
- [ ] 전체 flip lifecycle 8단계 검증 완료
- [ ] 모든 테스트 5초 이내 완료 (애니메이션 50-100ms)

**위험**: MEDIUM-HIGH — 멀티터치는 정밀한 타이밍/포인터 이벤트 필요, `ui.Image` 스냅샷 필요

---

## Phase V: 메모리 + 골든 + 불변속성

**목표**: 진짜 메모리 누수 검증(`WeakReference` + GC), 양면모드 골든 테스트, 형상 불변속성 속성기반 테스트 25+개.

**예상 작업량**: 1개 수정, 4개 생성 / ~300라인 추가 / PR #5

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/page_flip_memory_test.dart` | **수정** | WeakReference + GC pressure로 대체 |
| `test/page_flip_double_spread_golden_test.dart` | **생성** | 양면모드 골든 6개 |
| `test/effects/page_flip_geometry_invariants_test.dart` | **생성** | 속성기반 25개, 랜덤 파라미터 100조합 |
| `test/page_flip_painter_should_repaint_test.dart` | **생성** | shouldRepaint 21개 조건 전수 |
| `test/page_flip_large_itemcount_test.dart` | **생성** | 1000페이지 플립 100회 |

**핵심 추가 케이스**:
- **메모리**: Widget → WeakReference(state) → dispose → GC → target null 증명
- **메모리**: PreRenderManager snapshot → dispose → 모든 ui.Image disposed 확인
- **메모리**: DefaultPageFlipEffectHandler dispose → AudioPlayer 전부 해제
- **골든**: 양면모드 forward progress 0.0/0.5/0.95
- **골든**: 양면모드 backward progress 0.5, 다크테마, spine 경계
- **형상**: `flapVisibleWidth >= 0` 모든 progress
- **형상**: `foldX` in [spineX, width] 모든 모드
- **형상**: `shadowIntensity` 0 at 0/1, peak at 0.5
- **형상**: `curvatureAmount` 0 at 0/1
- **형상**: 100개 랜덤 (progress, touchOffset, size, mode, dir) → 모두 유효
- **형상**: 미러 대칭: (isForward, p) ↔ (!isForward, 1-p)
- **shouldRepaint**: 21개 필드 각각 변경 → true, 전부 동일 → false

**인수 조건**:
- [ ] WeakReference GC 테스트 통과 (VM only, web skip)
- [ ] 골든 테스트 CI 통과 (Linux + macOS 마스터 분리)
- [ ] 형상 불변속성 25+개 속성기반 검증, 100+ 랜덤 조합
- [ ] shouldRepaint 21개 조건 전수 검증

**위험**: MEDIUM-HIGH — 골든은 플랫폼 의존, GC 테스트는 환경 의존, 랜덤 시드 결정론적 고정

---

## Phase VI: 통합 + 플랫폼 채널 + 접근성

**목표**: 플랫폼 채널 호출 검증, 접근성 트리 검증, 방향(LTR/RTL) 일관성, 남은 분기 커버리지 완료.

**예상 작업량**: 3개 수정, 2개 생성 / ~250라인 추가 / PR #6

| 파일 | 작업 | 내용 |
|------|------|------|
| `test/page_flip_platform_channel_test.dart` | **생성** | MethodChannel mock 검증 8개 |
| `test/page_flip_accessibility_test.dart` | **생성** | Semantics 트리 검증 8개 |
| `test/page_flip_pdf_integration_test.dart` | 수정 | letterbox, 단면 비율, isRightSwipe 4개 |
| `test/page_flip_stress_test.dart` | 수정 | 방향전환, didUpdateWidget, setState 4개 |
| `test/page_flip_selectable_child_test.dart` | 수정 | 텍스트 선택, 히트테스트 3개 |

**핵심 추가 케이스**:
- Haptic `playTransient` → MethodChannel `invokeMethod` with intensity/sharpness
- Haptic `playSystemMedium` → `HapticFeedback.mediumImpact` fallback
- PlatformException → `HapticFeedback.lightImpact` (graceful degradation)
- Audio player: Opus → setSource → seek → resume 체인
- `enableSound: false` → `verifyNever` audio call
- Accessibility: `semanticBuilder` 커스텀 포맷 사용
- Accessibility: `onIncrease`/`onDecrease`/`onScrollLeft`/`onScrollRight` 매핑
- Accessibility: 마지막 페이지에서 `onIncrease` null
- Stress: forward→backward→forward 200ms 내 방향전환
- Stress: 부모 `setState` during active drag → 충돌 없음
- SelectableText: long press 선택 제스처 → 플립 안 함
- PDF: 16:9 letterbox 밴드 드래그 → 플립 성공
- `isRightSwipe: true` → gesture 의미 반전

**인수 조건**:
- [ ] 플랫폼 채널: 성공/실패 경로 모두 mock 검증
- [ ] 접근성: 경계 페이지(first/last)에서 Semantics 트리 정확
- [ ] Stress: 방향전환/위젯재빌드 중 충돌 없음
- [ ] LTR/RTL 미러 = 동일 플립 동작

**위험**: MEDIUM — 플랫폼 채널 mock은 `setMockMethodCallHandler` 의존, 접근성은 `tester.ensureSemantics()`, Stress는 시간 의존 (짧은 애니메이션 사용)

---

## Phase 의존성 그래프

```
Phase I (설정 + 중복제거)
  └──→ Phase II (상태컨트롤러)
         ├──→ Phase III (물리 + 위젯경계 + 성능프로필)
         │      └──→ Phase IV (양면모드 + 멀티터치)
         │             ├──→ Phase V (메모리 + 골든 + 불변속성)
         │             └──→ Phase VI (플랫폼채널 + 접근성 + 스트레스)
```

Phase IV/VI는 III 이후 III/V는 V 이후 병렬 가능 (파일이 다름).

---

## 중복 테스트 제거

| 삭제 파일 | 보유 파일 | 삭제 전 확인 |
|-----------|----------|------------|
| `test/physics_test.dart` | `test/physics/paper_physics_config_test.dart` + `paper_physics_frame_test.dart` | diff 검증: physics_test의 유일 assertion 이전 |
| `test/effects/clip_alignment_test.dart` | `test/effects/page_flip_clip_alignment_test.dart` | diff 검증 |
| `test/features/effects/default_page_flip_effect_handler_test.dart` | `test/widgets/default_page_flip_effect_handler_test.dart` | diff 검증 |

---

## 실행 시간 예산 (CI)

| Phase | 테스트 수 | 예상 시간 | 최대 목표 |
|-------|-----------|----------|----------|
| I | 55 | 8초 | 15초 |
| II | 45 | 12초 | 20초 |
| III | 60 | 15초 | 25초 |
| IV | 55 | 25초 | 40초 |
| V | 65 | 35초 | 50초 |
| VI | 50 | 20초 | 30초 |
| **Total** | **~330** | **~115초** | **< 300초** |

**애니메이션**: 모든 테스트는 `Duration(milliseconds: 50-100)` 사용, 기본값 450ms 절대 사용 금지.

---

## Phase VI 이후에도 남는 미검증 영역 (< 5%)

| 영역 | 이유 | 대안 |
|------|------|------|
| Android/iOS 네이티브 햅틱 구현 | 단위테스트 불가 | 기기 통합테스트 |
| GPU 셰이더 컴파일/텍스처 필터링 | 스크린샷 필요 | 기기 골든테스트 |
| AudioPlayer 동시 재생 타이밍 | 오디오 파이프라인 | 수동 QA |
| 60fps 성능 목표 | 벤치마크 인프라 필요 | flutter_driver benchmark |
| Web 플랫폼 | 패키지 범위 밖 | 별도 이슈 |

---

## 공통 테스트 유틸리티

`test/utils/test_helpers.dart`에 생성 (Phase I에서 시작, 이후 확장):

```dart
/// 단색 테스트 이미지 생성
Future<ui.Image> createTestImage(Size size, Color color);

/// 좌/우 다른 색상 spread 이미지 생성
Future<ui.Image> createSpreadImage(Size size, Color left, Color right);

/// No-op effect handler (플랫폼 채널 회피)
class NoOpEffectHandler implements PageFlipEffectHandler { ... }

/// AudioPlayer 3채널 mock 설정
void setupAudioMocks(TestDefaultBinaryMessengerBinding binding);

/// Haptic 채널 mock 설정
void setupHapticMock(TestDefaultBinaryMessengerBinding binding);

/// GC 강제 실행 (VM only, web skip)
Future<void> forceGC();
```
