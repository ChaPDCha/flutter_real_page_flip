# 레이아웃 제약 게이트 (무한 높이 방지)

## 왜 있는가

페이지 플립 사용 시 **성경 본문이 안 보이는** "RenderBox was not laid out" / "BoxConstraints forces an infinite height" 오류가 **여러 번 재발**했음.  
`Stack(fit: StackFit.expand)` 와 **Offstage** 로 숨긴 페이지도 레이아웃은 수행되므로, 무한 제약이 한 번 들어오면 모든 페이지(표시/비표시)가 깨짐.

## 이 패키지에서 건드리면 안 되는 부분

| 파일 | 역할 | 제거/완화 시 재발 |
|------|------|-------------------|
| **lib/src/page_flip_widget.dart** | `LayoutBuilder` 내 `needBounded` 일 때 `SizedBox(width: maxW, height: maxH)` 로 감싸기. `constrainedSize` 를 `PageFlipLayerView` 에 전달 | O |
| **lib/src/page_flip_layer_view.dart** | `constrainedSize` 파라미터 및 `_wrapWithConstraints()` 로 Offstage·현재·플립 중 페이지에 유한 크기 강제 | O |

## 수정 전에

- **단일 제약 게이트** 로직(무한이면 MediaQuery 로 유한 크기 계산 후 SizedBox/constrainedSize) 을 제거하거나 조건을 완화하지 말 것.
- **로컬 패키지** 이므로 수정 후 반드시 **전체 재빌드** (`flutter clean` 후 `flutter run`). 핫 리로드/리스타트로는 반영 안 됨.

전체 가이드: **`docs/flutter_layout_constraints_guide.md`** (재발 방지, 교훈, 체크리스트).
