# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2+5] - 2026-06-17
### 🐛 수정
- 페이지플립 접힌 면 바깥 경계선 클립 정렬 오차 수정 (screen-space clip path 도입)
- 챕터 제목에 하드코딩된 `fontFamily: 'serif'`를 사용자 설정 반영으로 수정

### 🔧 빌드/배포
- Firebase Crashlytics + Analytics + Remote Config 연동
- Crashlytics 전역 에러 핸들러 등록 (Flutter + Native)
- Firebase 초기화 실패 시 앱 크래시 방지 try-catch 추가
- AdMob 초기화 코드 누락 복구
- google-services.json .gitignore 추가 (시크릿 보호)
- 버전 1.0.2+5 (build number 5)

### ♻️ 리팩토링
- FirebaseService lazy getter 도입 (테스트 환경에서 자동 no-op)
- buildFlapScreenClipPath degenerate geometry 가드 추가

### 🧪 테스트
- clip_alignment_test.dart 18개 추가: stationary/flap 경로 정렬을 다양한 각도, 곡률, touch offset, double-spread 모드에서 검증
- snapClipCoord 정밀도 테스트

## [1.0.1+4] - 2026-06-17
### 🐛 수정
- 1단보기 페이지 넘김 시 현재 페이지가 사라지고 빈 종이로 보이던 문제 수정
- 이전페이지로 넘기기 시 접힌 면 틈새로 다른 글자가 보이던 문제 수정

### 🎨 UI/UX
- 배너 광고를 서재 화면으로만 이동 (읽기 중 방해 제거)

### 🔧 빌드/배포
- 비공개테스트 알파 트랙 배포
- 버전 1.0.1+4 (build number 4)

## [1.0.0+3] - 2026-06-17
### 🎨 UI/UX
- Play Store 등록정보 업데이트: 스크린샷 5종, 앱 설명 한글/영문 작성

### 🔧 빌드/배포
- 비공개테스트 배포 (internal testing track)
- 버전 1.0.0+3 (build number 3)

## [1.0.0+2] - 2026-06-17
### 🎨 UI/UX
- 배너 광고를 리더 화면 하단에 추가 (Adaptive anchored banner)

### 🔧 빌드/배포
- Play Store 출시 준비: 서명 설정, ProGuard, AdMob 통합
- 안드로이드 릴리스 번들 빌드 성공 (94.2MB)

## [1.4.2] - 2026-06-04
### Added
- Updated documentation to clarify that the engine is optimized for vertical mobile devices and does not support horizontal two-page view.

## [1.4.1] - 2026-06-04
### Changed
- Relicensed the package under the MIT License, making it completely free for commercial and non-commercial use.

## [1.4.0] - 2026-05-14
### Added
- **Direction-aware flip thresholds**: `cutoffForward` and `cutoffPrevious`
  independently control drag-release completion (both default to `0.4`).
- **12 new test files** covering `PageFlipConfig`, `PageFlipGeometry`,
  `PageFlipPainter`, `PaperPhysicsConfig`, `PaperPhysicsFrame`,
  `PaperResistanceModel`, `PaperTextureNoise`, `StickSlipController`,
  `PageFlipStateController`, `PreRenderManager`, and `EdgeTapFeedback`.
- **Named geometry constants**: 6 rendering constants extracted from inline
  magic numbers.

### Changed
- `PageFlipStateController` accepts `cutoffForward`/`cutoffPrevious` from
  `PageFlipConfig` instead of a hardcoded threshold.
- `PageFlipPainter` constructor is now `const`.
- `cutoffForward` default: `0.8` → `0.4`.
- `cutoffPrevious` default: `0.1` → `0.4`.

### Fixed
- `PageFlipConfig` equality: `==`/`hashCode` now include `enableHaptics`,
  `enableSound`, and `effectHandler`.
- `PaperPhysicsConfig` and `PaperPhysicsFrame` added `==`/`hashCode` overrides.

## [1.3.0] - 2026-05-09
### Added
- **Dark Mode Support**: `PageFlipConfig.backgroundColor` now defaults to `null`
  instead of `Colors.white`. When `null`, the engine reads
  `Theme.of(context).scaffoldBackgroundColor` at render time, so dark mode
  works automatically without any extra configuration.
- Adaptive shadow intensity in `PageFlipPainter`: backgrounds with luminance
  below 0.20 (dark mode) receive softer inner shadows (35 % → 20 %) and
  stronger fold highlights (12 % → 18 %) for a more natural flip appearance.
- New **Dark Mode Support** section in `README.md` with zero-config and
  custom-color examples.

### Changed
- `PageFlipConfig.backgroundColor` type changed from `Color` to `Color?`.
  Existing callers that explicitly pass a colour are unaffected; callers that
  relied on the `Colors.white` default now automatically inherit the host
  app's scaffold background colour.

## [1.2.4] - 2026-05-02
### Fixed
- Fixed a 404 error on the legacy interaction demo video URL which caused it to render as a plain link instead of embedding as a video player.

## [1.2.3] - 2026-05-02
### Fixed
- Replaced WebP and <img> tags with raw markdown video links to allow native video embedding on GitHub and clean fallback links on pub.dev.
- Removed legacy `realpageflip_sample.webp` to prevent display of inaccurate static recordings.

## [1.2.2] - 2026-05-02
### Fixed
- Fixed broken video tags on pub.dev by replacing them with clickable animated WebP thumbnails and Markdown text links.
- Removed redundant demo sections to ensure exactly two primary demo links are prominently displayed.

## [1.2.1] - 2026-05-02
### Added
- Replaced main demo with a high-fidelity, extended interaction recording.
- Added "Legacy Interaction Demo" section to showcase core physics and gesture arbitration.
- Integrated direct GitHub user-attachment URLs for robust documentation rendering.

## [1.2.0] - 2026-05-02
### Added
- Replaced demo assets with high-fidelity production sample (`realpageflip_sample.webp`).
- Optimized `README` for pub.dev compatibility with clickable high-resolution previews.
- Increased image width in documentation for better technical visualization.

## [1.1.3] - 2026-05-02
### Added
- Replaced static placeholder with a high-fidelity interaction recording of the actual engine.
- Fixed rendering issues in the documentation preview assets.

## [1.1.2] - 2026-05-02
### Added
- Improved snappy demo video with immediate interaction start (zero delay).
- Switched to absolute asset URLs in documentation for better rendering on pub.dev and other platforms.

## [1.1.1] - 2026-05-02
### Added
- Professional high-fidelity teaser video (demo.webp) for documentation.
- Comprehensive technical differentiation and GPU optimization guides in README.
- Standardized high-efficiency Opus audio assets for better performance.
- Enhanced example application with unique page content and heavy-load stress tests.
- GitHub repository SEO optimization (topics, description).

### Fixed
- Sync issues between internal package and public repository.

## [1.1.0] - 2026-05-01
### Added
- Physics-based interaction logic for realistic paper friction.
- Dynamic geometry rendering with hardware-accelerated clipping.
- Integrated haptic feedback system.
- Sound effect integration with `audioplayers`.
- Semantics support for accessibility.
- Strict linting and code formatting.

### Changed
- Refactored `PageFlipWidget` to use a more robust `PageFlipStateController`.
- Improved snapshot capturing logic in `PreRenderManager`.

### Fixed
- Layout boundary issues in certain `Stack` configurations.
- Memory leak in `PreRenderManager` snapshots.
