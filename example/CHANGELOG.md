# Changelog — Realbook App (example)

All notable changes to the Realbook example application will be documented here.
These versions use the `X.Y.Z+N` format matching Android versionCode for Play Store.

## [1.0.31+37] - 2026-06-27
### 🐛 수정
- 페이지 플립 소리가 재생되지 않던 버그 수정 (audioplayers resume/play 상태 처리) | Fixed page flip sound not playing due to incorrect audio state handling
- 햅틱 피드백이 MethodChannel 실패 시에도 기본 진동이 울리도록 폴백 추가 | Added HapticFeedback fallback when native haptic channel fails

## [1.0.30+36] - 2026-06-27
### ✨ 기능
- 앱 업데이트 로그를 Cloudflare Worker API에서 실시간으로 받아오도록 개선 | Release notes now fetched live from remote API instead of bundled-only

## [1.0.29+35] - 2026-06-27
### 🐛 수정
- 설정 패널 스위치가 Android 네비게이션 바에 가려지던 문제 수정 | Fixed settings panel switches hidden behind Android navigation bar

## [1.0.28+34] - 2026-06-27
### 🐛 수정
- 햅틱 피드백이 완전히 출력되지 않던 긴급 버그 수정 (screenWidth 정규화 상수 오류) | Fixed haptic feedback not firing due to screen width normalization regression

## [1.0.27+33] - 2026-06-26
### 🐛 수정
- 햅틱 피드백이 화면 크기에 따라 일관되지 않게 진동하던 문제 수정 (실제 기기 폭 기반 정규화)
- 장시간 사용 시 메모리 사용량이 증가하던 문제 수정 (physics 엔진 자동 정리)
- goToPage 프로그래매틱 네비게이션 안정성 개선

### ⚡ 성능
- 페이지플립 애니메이션 중 GPU compositing layer 오버헤드 감소

## [1.0.26+32] - 2026-06-26
### ✨ 기능
- 네이티브 햅틱 엔진(CoreHaptics / Composition)을 적용하여 더욱 세밀하고 고급스러운 페이지 플립 질감(Smooth/Standard/Textured/Kraft) 물리 반응 구현

## [1.0.25+31] - 2026-06-25
### 🐛 수정
- EPUB 목차(TOC) 페이지가 여러 페이지로 분할되어 표시되던 버그 수정 (epub:type="toc" 감지 후 제외)
- 가장자리 탭으로 챕터 경계 이동 시 페이지플립 제스처가 작동하지 않던 버그 수정 (PageFlipController 동기화)

## [1.0.24+30] - 2026-06-25
### ✨ 기능
- UI 10개 언어 지원 (한국어, 영어, 스페인어, 필리핀어, 프랑스어, 인도네시아어, 포르투갈어, 중국어, 일본어)
- slang 기반 i18n 시스템 구축 (type-safe, YAML 기반 번역 관리)
- 런타임 언어 전환 지원 (설정 저장)

### 🎨 UI/UX
- 모든 하드코딩 문자열 context.t.* 마이그레이션

### 🧪 테스트
- l10n 테스트 13개 추가 (모든 로케일 키 존재 검증)
- 위젯 테스트 TranslationProvider 호환성 수정

## [1.0.23+29] - 2026-06-24
### 🎨 UI/UX
- 앱 아이콘을 새로운 Realbook 브랜드 로고로 교체 (Android/iOS 전체 해상도)

## [1.0.22+28] - 2026-06-24
### ✨ 기능
- Firebase Crashlytics + Sentry 이중 오류 리포팅 시스템 구축
- 전역 오류 처리: Flutter 프레임워크 및 네이티브 영역 오류를 두 서비스에 동시 전송
- 모든 데이터베이스/동기화/읽기 화면 작업에 오류 추적 적용
- SentryFlutter 초기화 (--dart-define SENTRY_DSN 설정 시 활성화)

### ♻️ 리팩토링
- 서재 데모 콘텐츠를 별도 파일로 분리
- PageFlipPainter/Clippers를 part 파일로 추출하여 코어 라이브러리 코드 정리
- 햅틱 엔진 개선: iOS/Android 플랫폼별 질감 피드백 경로 분리, Weber-Fechner 비선형 진폭 곡선 적용

### 🧪 테스트
- SupabaseSyncClient 21개 단위 테스트 추가
- BookshelfSettingsPanel 15개 위젯 테스트 추가
- ReaderSettingsPanel 11개 위젯 테스트 추가
- DefaultPageFlipEffectHandler 20개 단위 테스트 추가
- 기존 테스트 업데이트 및 리팩토링 대응

## [1.0.21+27] - 2026-06-24
### 🎨 UI/UX
- Play Store 리스팅 아이콘을 신규 브랜드 로고로 교체

### 🐛 수정
- 햅틱 진동 엔진 전면 재설계: 이벤트별 고유 진동 시그니처 적용 (시작/더블탭/미끄러짐/질감)
- 물리 엔진 stickSlip 강도를 진동 세기에 반영하여 종이 넘김 촉감 현실화

## [1.0.20+26] - 2026-06-23
### 🐛 수정
- 페이지플립 햅틱 진동 출력 개선: Android에서 `Vibration.vibrate()` 모터 직접 구동으로 실제 진동 보장

## [1.0.19+25] - 2026-06-23
### 🔧 빌드/배포
- 엄격한 품질 게이트 준수를 위한 코드 포맷팅 및 린트 경고 교정 완료

## [1.0.18+24] - 2026-06-23
### 🐛 수정
- 1단보기 backward 페이지플립 foldX/flapMaterialWidth 방향을 forward와 통일하여 일관된 넘김 방향 보장

## [1.0.17+23] - 2026-06-22
### 🎨 UI/UX
- Bookshelf 화면 Sliver 기반 레이아웃으로 재설계 (BouncingScrollPhysics)
- ReaderTypography 도입: Noto Sans KR (UI), Outfit (기하학적), Serif/Sans (본문) 3가지 폰트 시스템
- BookshelfSettingsPanel 추가 (동기화 상태, 설정)
- 다크 테마로 통일

### 🐛 수정
- AdaptiveBannerAd initState → didChangeDependencies 이동으로 광고 중복 로드 방지
- 테스트 환경에서 Google Fonts 대신 기본 폰트 사용하도록 fallback 처리

## [1.0.15+21] - 2026-06-21
### ✨ 기능
- 앱 브랜딩 로고 전면 리뉴얼 및 전체 플랫폼(Android, iOS, macOS, Windows, Web) 앱 아이콘 교체 (기존 무한대 로고 폐기)
- 신규 투명배경 WebP 로고 탑재

### 🐛 수정
- 페이지 플립 지오메트리 엔진 코드 가독성 개선 (파일 분할 및 린트 경고 12건 완전 해결)

## [1.0.14+20] - 2026-06-21
### 🐛 수정
- 1단보기 햅틱 진동 세기 조절 버그 수정 및 최적화

## [1.0.13+19] - 2026-06-21
### 🐛 수정
- 앞으로 1단보기 페이지플립 콘텐츠 좌우 반전 버그 수정 (flipHorizontal 플래그 오류)

## [1.0.12+18] - 2026-06-21
### 🐛 수정
- 1단보기 forward 페이지플립 원래 방식으로 복원 (이동하는 접힘선)
- 1단보기 backward는 제본선 고정 + 손가락 방향 일치 유지
- snapshot 렌더링 filterQuality 복원 (medium)
- 불필요한 circular import 제거

## [1.0.11+17] - 2026-06-21
### 🐛 수정
- 1단보기 이전페이지 넘김 방향 수정 — 손가락(왼→오)과 flap 움직임이 반대였던 버그
- forward/backward 모두 왼쪽 제본선(x=0)에서 오른쪽으로 flap 확장 (flapRightOfFold 통일)

## [1.0.10+16] - 2026-06-21
### 🐛 수정
- 1단보기 접힘선(foldX)을 제본선에 고정 — 페이지가 뜯어지는 듯한 시각적 오류 해결
- forward: 스파인 왼쪽 고정(foldX=0), flap이 오른쪽으로 축소
- backward: 스파인 오른쪽 고정(foldX=pageWidth), flap이 왼쪽으로 성장
- flapRightOfFold 필드로 4개 모드 통합 (1단/2단 × forward/backward)
- 각도 제한, 곡선 방향, clip path, paint gradient 일괄 수정

### 🧪 테스트
- geometry/clip/paint rendering/golden 테스트 전면 업데이트 (448개 통과)

### 🔧 빌드/배포
- 비공개테스트(closed alpha) 트랙 배포

## [1.0.9+15] - 2026-06-20
### 🐛 수정
- backward flap clip bleed 방향 수정
- backward 단일 페이지 flap 전면 콘텐츠 수평 반전

### 🔧 빌드/배포
- 비공개테스트(closed alpha) 트랙 재배포

## [1.0.8+14] - 2026-06-20
### 🐛 수정
- 역방향 페이지 플립 flap이 foldX의 잘못된 방향에 위치하던 버그 수정
- freeEdgeX 필드 추가, buildFlapScreenClipPath backward용 별도 경로
- paint 메서드 gradient/fade 방향을 isForward에 따라 동적 전환

### 🧪 테스트
- backward flapLeft/freeEdgeX 검증 추가, golden 업데이트

## [1.0.7+13] - 2026-06-20
### 🐛 수정
- 역방향 페이지 플립 foldX 방향 수정
- floatProgress = 1 - dragProgress 반영

## [1.0.6+12] - 2026-06-20
### 🐛 수정
- 역방향 단일 페이지 플립에서 flap에 콘텐츠가 표시되지 않던 버그 수정

## [1.0.5+10] - 2026-06-20
### 🐛 수정
- 역방향 단일 페이지 플립이 왼쪽이 아닌 오른쪽에서 시작하던 버그 수정
- bend shading / edge-fade 그래디언트 방향 일원화

## [1.0.5+9] - 2026-06-20
### 🐛 수정
- 역방향 페이지 플립 foldX 방향 수정, clip/shading 방향 반전

## [1.0.4+7] - 2026-06-19
### 🧪 테스트
- 64개 테스트 추가 (총 387개)

## [1.0.3+6] - 2026-06-19
### ✨ 기능
- 2단 보기에서 페이지 뒷면 콘텐츠 2.5D 구현

## [1.0.2+5] - 2026-06-17
### 🐛 수정
- 페이지플립 접힌 면 클립 정렬 오차 수정
- Firebase 연동, Crashlytics 추가

## [1.0.1+4] - 2026-06-17
### 🐛 수정
- 1단보기 페이지 넘김 시 빈 종이로 보이던 문제 수정
- 광고를 서재 화면으로 이동

## [1.0.0+3] - 2026-06-17
### 🔧 빌드/배포
- Play Store 비공개테스트 첫 배포
