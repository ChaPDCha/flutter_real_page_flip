# Page Flip Engine — Animation Quality Fix Request

## Context

Flutter package `real_page_flip` (v1.5.0). High-fidelity 3D-like page flip engine with physics-based paper fold effects, mesh deformation, haptics, and audio.

**Problem**: Single-page mode page flip animations look unnatural. Both forward (next page) and backward (previous page) have visual defects that a human reader immediately notices as "wrong."

## Core Files

- `lib/src/effects/page_flip_engine.dart` — ALL geometry, painting, clipping, meshes (~1500 lines)
- `lib/src/page_flip_layer_view.dart` — Layer compositing (bottom/middle/flap stack)
- `lib/src/models/flip_layer_policy.dart` — Which content goes in which layer per mode
- `lib/src/controllers/page_flip_state_controller.dart` — Drag detection, progress tracking

## Current Known State (After Many Fix Attempts)

### Double-spread mode (2 pages side by side)
- Both forward and backward: **working correctly**. Fold line moves between edges/spine. Flap direction is correct. Do NOT change double-spread logic.

### Single-page mode — The Problems

**Forward (next page, swipe right→left)**:
- `foldX = pageWidth * (1.0 - progress)` — fold moves from right edge (pageWidth) to left edge (0)
- `flapRightOfFold = false` — flap extends LEFT of foldX
- `curveDirection = 1.0` — positive curvature
- `rawAngle = baseAngle` — not inverted
- `flipHorizontal = false` — no mirroring
- This is the ORIGINAL behavior that was working before backward fixes. But something in the paint method (gradients, fades, mesh mapping) may have been broken during refactoring.

**Backward (previous page, swipe left→right)**:
- `foldX = 0` — anchored at left spine
- `flapRightOfFold = true` — flap extends RIGHT of foldX
- `curveDirection = -1.0` — negative curvature
- `rawAngle = -baseAngle` — inverted
- `flipHorizontal = true` — mirrored content
- The flap follows the finger direction (left→right swipe = flap grows rightward). But the animation quality/feel is wrong.

### Key Fields on `PageFlipGeometry`
```
flapRightOfFold  // bool: true=flap extends RIGHT of foldX, false=LEFT
foldX            // double: x-position of fold/hinge line
flapLeft         // double: leftmost x of visible flap region  
freeEdgeX        // double: x of the lifted page edge (user "holds" this)
flapVisibleWidth // double: visible width after foreshortening
curveOffset      // double: bezier control point offset for paper curl
```

### `flapRightOfFold` Logic
```dart
flapRightOfFold = isDoubleSpread ? !isForward : !isForward;
// Simplifies to: !isForward
// Double forward:  false (flap LEFT)  — CORRECT
// Double backward: true  (flap RIGHT) — CORRECT  
// Single forward:  false (flap LEFT)  — RESTORED TO ORIGINAL
// Single backward: true  (flap RIGHT) — ANCHORED SPINE
```

### Angle Limits (single-page specific)
```dart
final flapSideWidth = isDoubleSpread ? flapMaterialWidth : pageWidth;
final revealedSideWidth = isDoubleSpread ? (...) : pageWidth;
```
Both set to `pageWidth` for single-page. May be too permissive — allows flap to rotate past natural limits.

### Paint Method — Direction-Dependent Code
Uses `g.flapRightOfFold` to determine:
- Highlight gradient direction (foldAlign/freeAlign)
- Fold-edge darkening direction
- Edge fade position and direction
- Fold fade position and direction
- `buildFlapScreenClipPath` path traversal order

## What "Correct" Should Look Like

### Single-page forward (swipe right→left, going to next page):
1. Crease forms at right edge, moves left across the page (like a wave)
2. Flap (already-turned portion) is BEHIND the crease (left side)
3. Page content on flap reads correctly (not mirrored)
4. As progress 0→1: flap grows from 0 to covering entire page, then snaps to next page
5. Revealed next page content shows on the RIGHT side of the fold

### Single-page backward (swipe left→right, going to previous page):
1. Spine is at LEFT edge (same as forward — it's a bound book)
2. Flap grows from spine (x=0) rightward, following the finger
3. Page content on flap may need mirroring (left-to-right peel shows back of page)
4. As dragProgress 0→1: flapVisibleWidth grows 0→pageWidth
5. Previous page content revealed on the RIGHT side of (or under) the flap
6. The fold line should be anchored at the left spine or move only slightly

## Known Bug History (For Context)

1. Original: foldX moved for both directions → user complained about "tearing" look
2. Fix attempt 1: Anchored both forward and backward at spine → forward looked "broken" 
3. Fix attempt 2: Restored forward to original moving crease, kept backward anchored → forward still has issues
4. `flipHorizontal` flag was accidentally inverted (`isForward` vs `!isForward`) — fixed
5. Linter removed `filterQuality: FilterQuality.medium` from snapshot rendering — restored
6. Circular import added by linter — removed

## Test Suite

448+ tests in `test/effects/`. Key test files:
- `page_flip_geometry_test.dart` — foldX, flapLeft, angle, curvature values
- `clip_alignment_test.dart` — stationary/flap/open clip path overlap
- `paint_rendering_test.dart` — edge fade, fold fade, highlight positions
- `flap_mesh_test.dart` — mesh vertex positions
- `page_flip_layer_view_golden_test.dart` — visual regression golden files

Run: `flutter test` from project root.

## What To Do

1. **Read** `lib/src/effects/page_flip_engine.dart` completely (especially the constructor `PageFlipGeometry` and `PageFlipPainter.paint`)
2. **Read** `lib/src/page_flip_layer_view.dart` to understand layer compositing
3. **Identify** the discrepancy between the physical model and the code
4. **Fix** the geometry/paint so both forward and backward look natural
5. **Update** tests to match new expectations
6. **Update** golden files: `flutter test test/page_flip_layer_view_golden_test.dart --update-goldens`

## How To Run & Test

```bash
cd H:/Automation/Realbook
flutter test                          # all 448+ tests
flutter test test/effects/            # effect tests only
flutter build appbundle               # build example app
cd example && python deploy_alpha.py  # deploy to Play Store alpha
```

## Project Structure
```
lib/
  src/effects/page_flip_engine.dart    ← 95% of the fix is here
  src/page_flip_layer_view.dart        ← layer stacking
  src/models/flip_layer_policy.dart    ← content allocation per mode
  src/controllers/                     ← drag/animation state
test/
  effects/page_flip_geometry_test.dart
  effects/clip_alignment_test.dart
  effects/paint_rendering_test.dart
  effects/flap_mesh_test.dart
  effects/flap_front_texture_test.dart
  page_flip_layer_view_golden_test.dart
```
