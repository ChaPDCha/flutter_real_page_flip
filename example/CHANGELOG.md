# Changelog — Realbook App (example)

All notable changes to the Realbook example application will be documented here.
These versions use the `X.Y.Z+N` format matching Android versionCode for Play Store.

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
