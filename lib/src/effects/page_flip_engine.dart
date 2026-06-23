/// Page flip engine — geometry, rendering, and gesture recognition.
///
/// This library is split into three parts:
/// - `page_flip_geometry.dart`: Constants, animation curves, and [PageFlipGeometry].
/// - `page_flip_gesture.dart`: [PageFlipGestureRecognizer] and arbitration.
/// - This file: Texture helpers, clip builders, mesh generation, widgets,
///   [PageFlipPainter], [PageFlipClipper], [PageFlipOpenClipper], and
///   opacity modulators.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

part 'page_flip_geometry.dart';
part 'page_flip_gesture.dart';

// ---------------------------------------------------------------------------
// Flap front texture helpers
// ---------------------------------------------------------------------------

/// Returns the source rect within a spread snapshot for the flipping flap front.
///
/// Forward double-spread: right half of the **current** spread (turning page).
/// Backward double-spread: left half of the **current** spread (turning page).
/// Spine reveal in layer 2 shows the adjacent spread half after crossing the spine.
/// Single-page (both directions): full page rect — the current page wraps onto
/// the flap so content is visible during the turn.
Rect? flapFrontSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
}) {
  if (isDoubleSpread) {
    final halfWidth = imageSize.width / 2;
    if (isForward) {
      return Rect.fromLTWH(halfWidth, 0, halfWidth, imageSize.height);
    }
    return Rect.fromLTWH(0, 0, halfWidth, imageSize.height);
  }

  return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
}

/// Returns the source rect within an adjacent spread snapshot for 2.5D back content.
///
/// The back of the flipping page shows the physically opposite half from the front:
/// - Forward double-spread: left half (verso of the right page = left page of next spread).
/// - Backward double-spread: right half (verso of the left page = right page of prev spread).
/// - Single mode: null (no back content).
///
/// Unlike [flapFrontSourceRect] which selects the page being peeled away, this
/// selects the page that lies on the other side of the paper — the one the reader
/// would see through thin paper as the flip progresses.
Rect? flapBackSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
}) {
  if (!isDoubleSpread) return null;
  final halfWidth = imageSize.width / 2;
  // The physically opposite half: forward → left half, backward → right half.
  if (isForward) {
    return Rect.fromLTWH(0, 0, halfWidth, imageSize.height);
  }
  return Rect.fromLTWH(halfWidth, 0, halfWidth, imageSize.height);
}

/// Destination rect on the canvas for mapping [flapFrontSourceRect] onto the flap.
Rect flapFrontDestRect({
  required Size size,
  required bool isDoubleSpread,
  required bool isForward,
}) {
  if (isDoubleSpread) {
    final halfWidth = size.width / 2;
    if (isForward) {
      return Rect.fromLTWH(halfWidth, 0, halfWidth, size.height);
    }
    return Rect.fromLTWH(0, 0, halfWidth, size.height);
  }

  return Rect.fromLTWH(0, 0, size.width, size.height);
}

/// Opacity of flap-front page content (0 = paper back only, 1 = full texture).
///
/// Three-phase curve to hide distorted text during the bend:
/// 1. Early drag (0 → [fadeOutEnd]): brief visibility, fast fade-out.
/// 2. Mid fold ([fadeOutEnd] → [revealStart]): paper back only.
/// 3. Late settle ([revealStart] → [revealEnd]): gentle content reveal.
@visibleForTesting
double flapFrontContentRevealOpacity(
  double progress, {
  double fadeOutEnd = 0.20,
  double revealStart = 0.85,
  double revealEnd = 0.95,
  bool isForward = true,
  bool isDoubleSpread = false,
}) {
  // Normalize progress so p always goes 0→1 from flip-start to flip-end.
  // Invert p for backward flips because their geometry is a reverse animation (progress goes 1→0).
  final invertProgress = !isForward;
  final p = invertProgress ? (1.0 - progress) : progress;

  // Phase 1: brief early visibility → fast hide as fold begins.
  if (p <= fadeOutEnd) {
    if (fadeOutEnd <= 0) return 0;
    final t = 1.0 - p / fadeOutEnd;
    return t * t * (3 - 2 * t);
  }

  // Phase 2: mid fold — paper back only (longest phase).
  if (p < revealStart) return 0;

  // Phase 3: late settle reveal.
  if (p >= revealEnd) return 1;
  final t = (p - revealStart) / (revealEnd - revealStart);
  return t * t * (3 - 2 * t);
}

/// Sub-pixel overlap (px) at layer seams (fold line, flap edge, spine reveal).
///
/// All clippers and [PageFlipPainter] use this value so [ClipPath] and canvas
/// clip boundaries stay aligned and hairline gaps do not appear.
const double kSpineRevealOverlapPx = 1.5;

/// Snaps a coordinate to half-pixel grid for consistent [ClipPath] / canvas clip.
@visibleForTesting
double snapClipCoord(double value) => (value * 2).round() / 2;

/// Applies [snapClipCoord] to a point, optionally shifting X by [overlapShift].
@visibleForTesting
Offset snapClipPoint(Offset point, {double overlapShift = 0}) => Offset(
      snapClipCoord(point.dx + overlapShift),
      snapClipCoord(point.dy),
    );

/// Appends the global fold-line boundary to [path] (caller must [Path.moveTo] first).
///
/// [overlapShift] moves the boundary along +X (stationary layer uses positive
/// bleed; open/revealed layer uses negative bleed so both layers overlap).
@visibleForTesting
void appendFoldLineBoundary(
  Path path,
  PageFlipGeometry geo, {
  double overlapShift = 0,
}) {
  final top = snapClipPoint(geo.foldLineTop, overlapShift: overlapShift);
  path.lineTo(top.dx, top.dy);

  if (geo.curvatureAmount > 0.001) {
    final control = snapClipPoint(
      geo.foldCurveControl,
      overlapShift: overlapShift,
    );
    final bottom = snapClipPoint(
      geo.foldLineBottom,
      overlapShift: overlapShift,
    );
    path.quadraticBezierTo(control.dx, control.dy, bottom.dx, bottom.dy);
  } else {
    final bottom = snapClipPoint(
      geo.foldLineBottom,
      overlapShift: overlapShift,
    );
    path.lineTo(bottom.dx, bottom.dy);
  }
}

/// Clip path for layer 2 (stationary spread half, left of fold + bleed).
@visibleForTesting
Path buildStationaryPageClipPath(Size size, PageFlipGeometry geo) {
  final path = Path()..moveTo(0, 0);
  appendFoldLineBoundary(
    path,
    geo,
    overlapShift: kSpineRevealOverlapPx,
  );
  path.lineTo(0, size.height);
  path.close();
  return path;
}

/// Clip path for layer 1 (revealed page, right of fold − bleed).
@visibleForTesting
Path buildOpenPageClipPath(Size size, PageFlipGeometry geo) {
  final path = Path()..moveTo(size.width, 0);
  appendFoldLineBoundary(
    path,
    geo,
    overlapShift: -kSpineRevealOverlapPx,
  );
  path.lineTo(size.width, size.height);
  path.close();
  return path;
}

/// Local-space flap region clip used by [PageFlipPainter] (matches fold seam).
@visibleForTesting
Path buildFlapClipPathLocal(
  PageFlipGeometry geo, {
  double foldEdgeBleedPx = kSpineRevealOverlapPx,
}) {
  final foldRight = snapClipCoord(geo.foldX + foldEdgeBleedPx);
  final flapLeft = snapClipCoord(geo.flapLeft);
  final height = geo.size.height;

  final path = Path();
  path.moveTo(flapLeft, 0);
  path.lineTo(foldRight, 0);

  if (geo.curvatureAmount > 0.001) {
    path.quadraticBezierTo(
      snapClipCoord(geo.foldX - geo.curveOffset + foldEdgeBleedPx),
      height / 2,
      foldRight,
      height,
    );
    path.lineTo(flapLeft, height);
    path.quadraticBezierTo(
      snapClipCoord(geo.flapLeft - geo.curveOffset),
      height / 2,
      flapLeft,
      0,
    );
  } else {
    path.lineTo(foldRight, height);
    path.lineTo(flapLeft, height);
  }
  path.close();
  return path;
}

/// Builds a triangle mesh that curves the flap texture along the fold and
/// flap-edge bezier curves so text and images bend with the paper.
///
/// Without this mesh, the flap content is drawn as a flat rectangle (affine
/// transform only) and looks like a flat board tilting rather than paper
/// curling. The mesh follows the quadratic bezier of both the fold line
/// and the flap edge, so every scanline maps to the correct curved position.
///
/// With [columns] >= 1, interior vertex columns are added between the fold
/// and flap edge. Each interior column has an amplified bezier offset (bulge)
/// that peaks at the midpoint, creating a convex 3D surface curvature effect.
/// Without this bulge the surface is a flat ruled plane between two curves —
/// text appears stiff rather than printed on curling paper.
///
/// [segments] vertical subdivisions (higher = smoother, default 16).
/// [columns] horizontal subdivisions (0 = fold-to-flap only, 4+ recommended).
@visibleForTesting
ui.Vertices buildFlapContentMesh({
  required Size size,
  required double foldX,
  required double flapLeft,
  required double curveOffset,
  required Rect srcRect,
  int segments = 16,
  int columns = 4,
  bool flipHorizontal = false,
}) {
  final height = size.height;
  final totalCols = columns + 2; // fold + interior + flap edge columns
  final rows = segments + 1;

  // -----------------------------------------------------------------------
  // 1. Build vertex grid [rows] × [totalCols] in a flat array.
  //
  // Pre-sized flat arrays avoid per-frame allocation of 4 × List<Float64List>
  // (previously 68+ small objects per call at default params). At 60fps this
  // eliminates ~24,000 micro-allocations/sec and the resulting GC pauses.
  //
  //   fold  col1  col2  col3  col4  flap
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row 0 (top)
  //    │╲    │     │     │     │    ╱│
  //    │ ╲   │     │ ╶───→│     │   ╱ │   bulge peak (more left shift)
  //    │  ╲  │     │     │     │  ╱  │
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row N (bottom)
  // -----------------------------------------------------------------------
  final gridSize = rows * totalCols;
  final gridX = Float64List(gridSize);
  final gridY = Float64List(gridSize);
  final gridU = Float64List(gridSize);
  final gridV = Float64List(gridSize);

  // Surface bulge factor: how much extra curvature interior columns get.
  // 30% additional bezier offset at the midpoint column creates visible
  // 3D curvature without looking like tightly rolled paper.
  const kBulgeStrength = 0.30;
  final colScale = 1.0 / (totalCols - 1);

  for (var i = 0; i < rows; i++) {
    final t = i / segments;
    final y = height * t;
    // Vertical quadratic bezier blend: 2(1-t)t — peak at t=0.5, zero at ends.
    final b = 2 * (1 - t) * t;
    final rowBase = i * totalCols;

    for (var j = 0; j < totalCols; j++) {
      final s = j * colScale; // 0 at fold, 1 at flap edge

      // Interior columns get amplified bezier offset → surface bulge.
      // sin(s*pi) peaks at s=0.5 and is zero at both edges, so the bulge
      // smoothly blends to the existing fold/flap edge positions.
      final bulgeScale = columns > 0 ? math.sin(s * math.pi) : 0.0;
      final colCurveScale = 1.0 + kBulgeStrength * bulgeScale;
      final colOffset = curveOffset * colCurveScale;

      // Column bezier-fold position at this row.
      final foldAtY = foldX - colOffset * b;
      final flapAtY = flapLeft - colOffset * b;

      final idx = rowBase + j;
      // Interpolate X between fold and flap edge for this column.
      gridX[idx] = foldAtY + (flapAtY - foldAtY) * s;
      gridY[idx] = y;
      // UV: right→left from srcRect.right (fold) to srcRect.left (flap edge).
      // flipHorizontal for mirrored 2.5D back content on double-spread.
      gridU[idx] = flipHorizontal
          ? srcRect.left + s * srcRect.width
          : srcRect.right - s * srcRect.width;
      gridV[idx] = srcRect.top + t * srcRect.height;
    }
  }

  // -----------------------------------------------------------------------
  // 2. Triangle pairs from the vertex grid (2 triangles per quad).
  //
  //  (i,j) ─── (i,j+1)
  //    | ╲     |
  //    |  ╲    |
  //  (i+1,j) ─ (i+1,j+1)
  //
  // T1: (i,j), (i+1,j), (i,j+1)
  // T2: (i,j+1), (i+1,j), (i+1,j+1)
  //
  // Pre-sized output arrays: 2 triangles × 3 vertices × 2 coords per quad,
  // total quads = segments × (totalCols - 1).
  // -----------------------------------------------------------------------
  final triCount = segments * (totalCols - 1) * 2;
  final positions = Float32List(triCount * 6);
  final texCoords = Float32List(triCount * 6);
  var offset = 0;

  for (var i = 0; i < segments; i++) {
    final row0 = i * totalCols;
    final row1 = (i + 1) * totalCols;
    for (var j = 0; j < totalCols - 1; j++) {
      final i0j0 = row0 + j;
      final i0j1 = row0 + j + 1;
      final i1j0 = row1 + j;
      final i1j1 = row1 + j + 1;

      // Triangle 1: (i,j), (i+1,j), (i,j+1)
      positions[offset] = gridX[i0j0];
      texCoords[offset++] = gridU[i0j0];
      positions[offset] = gridY[i0j0];
      texCoords[offset++] = gridV[i0j0];
      positions[offset] = gridX[i1j0];
      texCoords[offset++] = gridU[i1j0];
      positions[offset] = gridY[i1j0];
      texCoords[offset++] = gridV[i1j0];
      positions[offset] = gridX[i0j1];
      texCoords[offset++] = gridU[i0j1];
      positions[offset] = gridY[i0j1];
      texCoords[offset++] = gridV[i0j1];

      // Triangle 2: (i,j+1), (i+1,j), (i+1,j+1)
      positions[offset] = gridX[i0j1];
      texCoords[offset++] = gridU[i0j1];
      positions[offset] = gridY[i0j1];
      texCoords[offset++] = gridV[i0j1];
      positions[offset] = gridX[i1j0];
      texCoords[offset++] = gridU[i1j0];
      positions[offset] = gridY[i1j0];
      texCoords[offset++] = gridV[i1j0];
      positions[offset] = gridX[i1j1];
      texCoords[offset++] = gridU[i1j1];
      positions[offset] = gridY[i1j1];
      texCoords[offset++] = gridV[i1j1];
    }
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    textureCoordinates: texCoords,
  );
}

/// Clip rect for flap-side drop shadows in [PageFlipPainter].
///
/// Double-spread: right half only. Single-page: region to the right of the fold
/// so shadows are not painted over the stationary middle layer (layer 2).
@visibleForTesting
Rect flipSideShadowClipRect(PageFlipGeometry geo) {
  if (geo.isDoubleSpread) {
    return Rect.fromLTWH(
      geo.spineX,
      0,
      geo.size.width - geo.spineX,
      geo.size.height,
    );
  }
  final left = geo.foldX.clamp(0.0, geo.size.width);
  return Rect.fromLTWH(left, 0, geo.size.width - left, geo.size.height);
}

/// Clips [child] to the left or right half when [child] already spans the
/// full viewport-sized spread (snapshot or live two-page layout).
///
/// Use this in `PageFlipLayerView` flip layers. Do **not** pair with
/// [FractionallySizedBox] — that would double horizontal scale and stretch
/// spread snapshots via [BoxFit.fill].
Widget clipFullSpreadHalf({
  required Widget child,
  required Alignment alignment,
}) =>
    ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.5,
        child: child,
      ),
    );

/// Clips [child] to the left or right half when [child] lives in a **half-width**
/// slot (e.g. [Expanded] in a [Row]) and must be expanded to full spread width
/// before clipping — typical host `itemBuilder` layouts.
Widget clipSpreadPageHalf({
  required Widget child,
  required Alignment alignment,
}) =>
    ClipRect(
      child: Align(
        alignment: alignment,
        widthFactor: 0.5,
        child: FractionallySizedBox(
          widthFactor: 2,
          alignment: alignment,
          child: child,
        ),
      ),
    );

/// Displays a pre-render snapshot at [viewportSize] without aspect distortion.
///
/// Snapshots are captured at logical viewport dimensions; [BoxFit.fill] in a
/// matching [SizedBox] preserves proportions identical to the idle live page.
Widget buildViewportSnapshotImage(
  ui.Image image, {
  required Size viewportSize,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) {
    return RawImage(image: image, fit: BoxFit.fill);
  }
  return SizedBox(
    width: viewportSize.width,
    height: viewportSize.height,
    child: RawImage(
      image: image,
      fit: BoxFit.fill,
    ),
  );
}

/// Screen-space flap region clip used by [PageFlipPainter] BEFORE canvas transform.
///
/// Unlike [buildFlapClipPathLocal] (which operates in transformed local space),
/// this path follows the actual fold line and flap edge in screen space so it
/// exactly matches the clip of Layer 2 (stationary page), eliminating the seam
/// where wrong content shows through.
@visibleForTesting
Path buildFlapScreenClipPath(
  PageFlipGeometry geo, {
  double foldEdgeBleedPx = kSpineRevealOverlapPx,
}) {
  // Degenerate geometry guard.
  final degenerate = geo.flapRightOfFold
      ? geo.flapVisibleWidth <= 0.5
      : geo.flapLeft >= geo.foldX - 0.5;
  if (degenerate) return Path();

  final flapEdgeTop = snapClipPoint(geo.flapEdgeTop);
  final flapEdgeBottom = snapClipPoint(geo.flapEdgeBottom);

  final path = Path();

  if (!geo.flapRightOfFold) {
    // Flap spans LEFT of foldX.
    // Path: free edge (left) → fold line (right) → bottom → back to free edge.
    path.moveTo(flapEdgeTop.dx, flapEdgeTop.dy);
    appendFoldLineBoundary(path, geo, overlapShift: foldEdgeBleedPx);
    path.lineTo(flapEdgeBottom.dx, flapEdgeBottom.dy);
    if (geo.curvatureAmount > 0.001) {
      final control = snapClipPoint(geo.flapCurveControl);
      path.quadraticBezierTo(
        control.dx,
        control.dy,
        flapEdgeTop.dx,
        flapEdgeTop.dy,
      );
    }
  } else {
    // Flap spans RIGHT of foldX.
    // Path: fold line (left) → free edge (right) → bottom → back to fold line.
    final foldLineTop =
        snapClipPoint(geo.foldLineTop, overlapShift: -foldEdgeBleedPx);
    final foldLineBottom =
        snapClipPoint(geo.foldLineBottom, overlapShift: -foldEdgeBleedPx);
    path.moveTo(foldLineTop.dx, foldLineTop.dy);
    path.lineTo(flapEdgeTop.dx, flapEdgeTop.dy);
    path.lineTo(flapEdgeBottom.dx, flapEdgeBottom.dy);
    path.lineTo(foldLineBottom.dx, foldLineBottom.dy);
    if (geo.curvatureAmount > 0.001) {
      final control =
          snapClipPoint(geo.foldCurveControl, overlapShift: -foldEdgeBleedPx);
      path.quadraticBezierTo(
        control.dx,
        control.dy,
        foldLineTop.dx,
        foldLineTop.dy,
      );
    }
  }

  path.close();
  return path;
}

/// Computes an overall flap opacity multiplier based on flip [progress] for
/// thin-paper and end-reveal effects.
///
/// [progress] is the raw flip progress (0 = start edge, 1 = end edge of the
/// fold travel). The function internally normalizes via [isForward] so the
/// effect always activates at the right time regardless of direction.
///
/// Returns 1.0 (fully opaque) when both strengths are 0 or at extremes.
/// At mid-flip the paper becomes semi-transparent ([thinPaperStrength]).
/// Near the end of the flip the flap fades further ([endRevealStrength]) so
/// the next page content from layers below shows through.
@visibleForTesting
double flapOpacityModulator(
  double progress, {
  double thinPaperStrength = 0.15,
  double endRevealStrength = 0.35,
  double endRevealStart = 0.85,
  bool isForward = true,
  bool isDoubleSpread = false,
}) {
  // Normalize so p always goes 0→1 from start to end of the flip.
  // Invert p for backward flips because their geometry is a reverse animation (progress goes 1→0).
  final invertProgress = !isForward;
  final p = invertProgress ? (1.0 - progress) : progress;

  if (p <= 0 || p >= 1) return 1;
  if (thinPaperStrength <= 0 && endRevealStrength <= 0) return 1;

  // Thin paper: sin(p * π) peaks at p = 0.5 (mid-flip).
  final thinFactor = math.sin(p * math.pi) * thinPaperStrength;

  // End reveal: smoothstep from [endRevealStart] to 1.0.
  final revealT =
      ((p - endRevealStart) / (1.0 - endRevealStart)).clamp(0.0, 1.0);
  final endFactor = (revealT * revealT * (3 - 2 * revealT)) * endRevealStrength;

  return (1.0 - thinFactor - endFactor).clamp(0.2, 1.0);
}

///
/// PERFORMANCE CRITICAL: This painter is called 60 times per second during animation.
class PageFlipPainter extends CustomPainter {
  /// Creates a [PageFlipPainter] with the given animation state.
  const PageFlipPainter({
    /// Normalised flip progress from 0.0 to 1.0.
    required this.progress,

    /// Whether the flip direction is right-to-left.
    required this.isRightToLeft,

    /// Touch offset used to compute the fold angle.
    required this.touchOffset,

    /// The color of the paper back (flipping page's back side).
    required this.paperBackColor,

    /// How much the paper appears translucent at mid-flip (0.0–1.0).
    this.thinPaperStrength = 0.0,

    /// How much the next page content shows through at end of flip (0.0–1.0).
    this.endRevealStrength = 0.0,

    /// True if rendering for a dual spread book.
    this.isDoubleSpread = false,

    /// True if we are flipping forward.
    this.isForward = true,

    /// The opacity of the paper flap back side.
    this.paperOpacity = 1.0,

    /// Progress (0–1) by which flap-front content is fully hidden during fold.
    this.flapContentFadeOutEnd = 0.20,

    /// Progress (0–1) before late settle content begins fading in.
    this.flapContentRevealStart = 0.85,

    /// Progress (0–1) at which flap-front content is fully visible.
    this.flapContentRevealEnd = 0.95,

    /// Pre-captured snapshot of the flipping page front (flap texture).
    this.flapFrontImage,

    /// Source rect within [flapFrontImage] to map onto the flap.
    this.flapFrontSrcRect,

    /// Destination rect for [flapFrontSrcRect] on the canvas (defaults to right page).
    this.flapFrontDestRect,

    /// Pre-captured snapshot for 2.5D page back content (double-spread only).
    this.flapBackImage,

    /// Source rect within [flapBackImage] for the mirrored back texture.
    this.flapBackSrcRect,

    /// How visible the back content is (0.0–1.0, default 0.3).
    /// 0 = disabled, 0.3 = subtle mirror-through-paper effect.
    this.flapBackStrength = 0.0,

    /// Pre-computed geometry shared with clippers (avoids redundant construction).
    this.geo,

    /// Performance profile to control mesh density and shadows.
    this.performanceProfile = DevicePerformanceProfile.high,
  });

  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// The color of the paper back (flipping page's back side).
  final Color paperBackColor;

  /// How much the paper appears translucent at mid-flip (0.0–1.0).
  final double thinPaperStrength;

  /// How much the next page content shows through at end of flip (0.0–1.0).
  final double endRevealStrength;

  /// True if rendering for a dual spread book.
  final bool isDoubleSpread;

  /// True if we are flipping forward.
  final bool isForward;

  /// The opacity of the paper flap back side.
  final double paperOpacity;

  /// Progress (0–1) by which flap-front content is fully hidden during fold.
  final double flapContentFadeOutEnd;

  /// Progress (0–1) before late settle content begins fading in.
  final double flapContentRevealStart;

  /// Progress (0–1) at which flap-front content is fully visible.
  final double flapContentRevealEnd;

  /// Pre-captured snapshot of the flipping page front (flap texture).
  final ui.Image? flapFrontImage;

  /// Source rect within [flapFrontImage] to map onto the flap.
  final Rect? flapFrontSrcRect;

  /// Destination rect for flap front texture (null = legacy right-page mapping).
  final Rect? flapFrontDestRect;

  /// Pre-captured snapshot for 2.5D page back content (double-spread only).
  final ui.Image? flapBackImage;

  /// Source rect within [flapBackImage] for the mirrored back texture.
  final Rect? flapBackSrcRect;

  /// How visible the back content is (0.0–1.0, default 0.3).
  final double flapBackStrength;

  /// Pre-computed geometry (avoids redundant construction in paint).
  final PageFlipGeometry? geo;

  /// Performance profile to control mesh density and shadows.
  final DevicePerformanceProfile performanceProfile;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) {
      return;
    }

    // Use pre-computed geo when available; otherwise construct here
    // (backward compatible when geo is not passed).
    final g = geo ??
        PageFlipGeometry(
          progress: progress,
          isRightToLeft: isRightToLeft,
          touchOffset: touchOffset,
          size: size,
          isDoubleSpread: isDoubleSpread,
          isForward: isForward,
        );

    // Determine dark mode from paper luminance.
    final luminance = paperBackColor.computeLuminance();
    final isPaperDark = luminance < 0.20; // catches dark mode backgrounds

    canvas.save();

    // Clip to flap region in SCREEN space (before canvas transform) so the
    // clip exactly matches Layer 2's stationary clip along the same fold line,
    // preventing the seam where wrong content shows through.
    final flapRect = Rect.fromLTWH(
      g.flapLeft,
      0,
      g.flapVisibleWidth + kSpineRevealOverlapPx,
      size.height,
    );

    canvas.clipPath(buildFlapScreenClipPath(g));

    // Overall flap opacity modulation (thin paper + end reveal).
    // saveLayer composites everything inside at reduced opacity so the
    // underlying page content shows through — like real translucent paper.
    final flapAlpha = flapOpacityModulator(
      progress,
      thinPaperStrength: thinPaperStrength,
      endRevealStrength: endRevealStrength,
      isForward: isForward,
      isDoubleSpread: isDoubleSpread,
    );
    final needsLayer = flapAlpha < 0.995;
    if (needsLayer) {
      canvas.saveLayer(
          null, Paint()..color = Colors.white.withValues(alpha: flapAlpha),);
    }

    canvas.transform(g.transform.storage);

    // Layer 1: Paper back underlay, then flap-front texture with late reveal.
    final paperPaint = Paint()
      ..color = paperBackColor.withValues(
        alpha: paperOpacity == 1.0
            ? 1.0
            : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0),
      );
    canvas.drawRect(flapRect, paperPaint);

    // Layer 2: 2.5D page back content (double-spread only).
    // Shows the destination page content horizontally mirrored at low opacity,
    // creating the illusion of seeing through thin paper to the back side.
    final hasFlapBack =
        flapBackImage != null && flapBackSrcRect != null && isDoubleSpread;
    if (hasFlapBack && g.flapVisibleWidth >= 8.0) {
      var segments = 16;
      var columns = 4;
      if (performanceProfile == DevicePerformanceProfile.low) {
        segments = 8;
        columns = 1;
      } else if (performanceProfile == DevicePerformanceProfile.medium) {
        segments = 12;
        columns = 2;
      }

      final backMesh = buildFlapContentMesh(
        size: size,
        foldX: g.foldX,
        flapLeft: g.freeEdgeX,
        curveOffset: g.curveOffset,
        srcRect: flapBackSrcRect!,
        segments: segments,
        columns: columns,
        flipHorizontal: true,
      );
      canvas.drawVertices(
        backMesh,
        BlendMode.srcOver,
        Paint()
          ..shader = ui.ImageShader(
            flapBackImage!,
            ui.TileMode.clamp,
            ui.TileMode.clamp,
            _identityMatrixStorage,
          )
          ..filterQuality = FilterQuality.medium,
      );

      // Fade the back content into the paper by flapBackStrength so it looks
      // like a subtle bleed-through rather than a full texture layer.
      final backFadeAlpha = (1.0 - flapBackStrength).clamp(0.0, 1.0);
      if (backFadeAlpha > 0.005) {
        canvas.drawRect(
          flapRect,
          Paint()
            ..blendMode = BlendMode.srcOver
            ..color = paperBackColor.withValues(alpha: backFadeAlpha),
        );
      }
    }

    final hasFlapTexture = flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final contentReveal = flapFrontContentRevealOpacity(
        progress,
        fadeOutEnd: flapContentFadeOutEnd,
        revealStart: flapContentRevealStart,
        revealEnd: flapContentRevealEnd,
        isForward: isForward,
        isDoubleSpread: isDoubleSpread,
      );
      if (contentReveal > 0.001) {
        final srcRect = flapFrontSrcRect!;

        // Minimum width guard: flap narrower than 8 px compresses the full
        // page texture into garbage. Paper underlay + fade overlay handle
        // this scale — skip the mesh entirely.
        if (g.flapVisibleWidth >= 8.0) {
          // Build a triangle mesh that follows the bezier curves so text and
          // images appear to bend with the paper — not a flat board tilting.
          // 16 vertical segments × 6 horizontal columns (4 interior) with
          // surface bulge creates a convex 3D paper curl effect.
          var segments = 16;
          var columns = 4;
          if (performanceProfile == DevicePerformanceProfile.low) {
            segments = 8;
            columns = 1;
          } else if (performanceProfile == DevicePerformanceProfile.medium) {
            segments = 12;
            columns = 2;
          }

          final mesh = buildFlapContentMesh(
            size: size,
            foldX: g.foldX,
            flapLeft: g.freeEdgeX,
            curveOffset: g.curveOffset,
            srcRect: srcRect,
            segments: segments,
            columns: columns,
          );
          canvas.drawVertices(
            mesh,
            BlendMode.srcOver,
            Paint()
              ..shader = ui.ImageShader(
                flapFrontImage!,
                ui.TileMode.clamp,
                ui.TileMode.clamp,
                _identityMatrixStorage,
              )
              ..filterQuality = FilterQuality.medium,
          );

          // Fade mesh away during early fold / late settle using paper-colour
          // overlay so content does not pop in/out harshly.
          final fadeAlpha = (1.0 - contentReveal).clamp(0.0, 1.0);
          if (fadeAlpha > 0.005) {
            canvas.drawRect(
              flapRect,
              Paint()
                ..blendMode = BlendMode.srcOver
                ..color = paperBackColor.withValues(alpha: fadeAlpha),
            );
          }
        }
      }
    }

    // Layer 2–3: Subtle paper-bend shading
    //
    // A gentle highlight across the flap centre and faint darkening at the
    // fold edge. Strong enough to suggest a curved surface, soft enough not
    // to look like the paper is tightly rolled.
    // Fold side vs free-edge side determined by flapRightOfFold.
    final bendStrength = g.shadowIntensity; // 0–1, peaks mid-flip
    if (bendStrength > 0.005 &&
        performanceProfile != DevicePerformanceProfile.low) {
      // Fold-side alignment: where the flap meets the page.
      final foldAlign = g.flapRightOfFold
          ? Alignment.centerLeft // fold on left, flap extends right
          : Alignment.centerRight; // fold on right, flap extends left
      // Free-edge alignment: the lifted page edge.
      final freeAlign =
          g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;

      // Gentle centre highlight (catches light on the bulge).
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: freeAlign,
            end: foldAlign,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.12 * bendStrength),
              Colors.white.withValues(alpha: 0.08 * bendStrength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          ).createShader(flapRect),
      );

      // Subtle fold-edge darkening.
      final foldShadow = (isPaperDark ? 0.10 : 0.15) * bendStrength;
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            begin: foldAlign,
            end: freeAlign,
            colors: [
              Colors.black.withValues(alpha: foldShadow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25],
          ).createShader(flapRect),
      );
    }

    // Edge-fade: mask partial-text artifacts at the flap's free edge.
    // A ~8 px gradient from paperBackColor → transparent hides stray character
    // fragments at the mesh boundary without affecting visible flap content.
    const double edgeFadeWidth = 8;
    final edgeFadeRect = g.flapRightOfFold
        ? Rect.fromLTWH(
            g.freeEdgeX - edgeFadeWidth, 0, edgeFadeWidth, size.height,)
        : Rect.fromLTWH(g.flapLeft, 0, edgeFadeWidth, size.height);
    final edgeFadeBegin =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final edgeFadeEnd =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    canvas.drawRect(
      edgeFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: edgeFadeBegin,
          end: edgeFadeEnd,
          colors: [
            paperBackColor.withValues(alpha: 1),
            Colors.transparent,
          ],
        ).createShader(edgeFadeRect),
    );

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    // As the flap narrows near the fold line, texture pixels compress and
    // create visible fragments. This narrow gradient from paperBackColor →
    // transparent softens the fold boundary edge.
    const double foldFadeWidth = 6;
    final foldFadeRect = g.flapRightOfFold
        ? Rect.fromLTWH(g.foldX, 0, foldFadeWidth, size.height)
        : Rect.fromLTWH(g.foldX - foldFadeWidth, 0, foldFadeWidth, size.height);
    final foldFadeBegin =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final foldFadeEnd =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    canvas.drawRect(
      foldFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: foldFadeBegin,
          end: foldFadeEnd,
          colors: [
            paperBackColor.withValues(alpha: 1),
            Colors.transparent,
          ],
        ).createShader(foldFadeRect),
    );

    if (needsLayer) canvas.restore();

    canvas.restore();

    // Revealed Page Shadow
    canvas.save();
    canvas.clipRect(flipSideShadowClipRect(g));
    canvas.transform(g.transform.storage);

    final shadowWidth = _kRevealedShadowWidth * g.shadowIntensity;
    final revealedAlpha = 0.15 * g.shadowIntensity;
    if (revealedAlpha > 0.01 && shadowWidth > 1) {
      final revealedRect = Rect.fromLTWH(
        g.foldX,
        0,
        shadowWidth,
        size.height,
      );
      if (performanceProfile == DevicePerformanceProfile.low) {
        canvas.drawRect(
          revealedRect,
          Paint()..color = Colors.black.withValues(alpha: revealedAlpha * 0.5),
        );
      } else {
        canvas.drawRect(
          revealedRect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Colors.black.withValues(alpha: revealedAlpha),
                Colors.transparent,
              ],
            ).createShader(revealedRect),
        );
      }
    }
    canvas.restore();

    // Stationary Page Shadow (double-spread only; single-page stationary layer is
    // left of the fold and must not receive transformed shadows from the flip side).
    if (isRightToLeft && isDoubleSpread) {
      canvas.save();
      canvas.clipRect(flipSideShadowClipRect(g));
      canvas.transform(g.transform.storage);

      final stationaryWidth = _kStationaryShadowWidth * g.shadowIntensity;
      final stationaryAlpha = 0.05 * g.shadowIntensity;
      if (stationaryAlpha > 0.01 && stationaryWidth > 1) {
        final stationaryRect = Rect.fromLTWH(
          g.foldX - g.flapVisibleWidth - stationaryWidth,
          0,
          stationaryWidth,
          size.height,
        );
        if (performanceProfile == DevicePerformanceProfile.low) {
          canvas.drawRect(
            stationaryRect,
            Paint()
              ..color = Colors.black.withValues(alpha: stationaryAlpha * 0.5),
          );
        } else {
          canvas.drawRect(
            stationaryRect,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.black.withValues(alpha: stationaryAlpha),
                  Colors.transparent,
                ],
              ).createShader(stationaryRect),
          );
        }
      }
      canvas.restore();
    }

    // Center spine groove (double-spread): keep on the flip side so layer 2
    // stationary halves are not darkened.
    if (isDoubleSpread && progress > 0) {
      const spineShadowWidth = 18.0;
      canvas.save();
      canvas.clipRect(flipSideShadowClipRect(g));
      final spineRect = Rect.fromLTWH(
        g.spineX,
        0,
        spineShadowWidth,
        size.height,
      );
      if (performanceProfile == DevicePerformanceProfile.low) {
        canvas.drawRect(
          spineRect,
          Paint()
            ..blendMode = BlendMode.multiply
            ..color = Colors.black.withValues(alpha: 0.04 * g.shadowIntensity),
        );
      } else {
        canvas.drawRect(
          spineRect,
          Paint()
            ..blendMode = BlendMode.multiply
            ..shader = LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.09 * g.shadowIntensity),
                Colors.transparent,
              ],
            ).createShader(spineRect),
        );
      }
      canvas.restore();
    }
  }

  /// Only repaints when animation-critical values change.
  @override
  bool shouldRepaint(covariant PageFlipPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.touchOffset != touchOffset ||
      oldDelegate.isRightToLeft != isRightToLeft ||
      oldDelegate.paperBackColor != paperBackColor ||
      oldDelegate.isDoubleSpread != isDoubleSpread ||
      oldDelegate.isForward != isForward ||
      oldDelegate.paperOpacity != paperOpacity ||
      oldDelegate.flapContentFadeOutEnd != flapContentFadeOutEnd ||
      oldDelegate.thinPaperStrength != thinPaperStrength ||
      oldDelegate.endRevealStrength != endRevealStrength ||
      oldDelegate.flapContentRevealStart != flapContentRevealStart ||
      oldDelegate.flapContentRevealEnd != flapContentRevealEnd ||
      oldDelegate.flapFrontImage != flapFrontImage ||
      oldDelegate.flapFrontSrcRect != flapFrontSrcRect ||
      oldDelegate.flapFrontDestRect != flapFrontDestRect ||
      oldDelegate.flapBackImage != flapBackImage ||
      oldDelegate.flapBackSrcRect != flapBackSrcRect ||
      oldDelegate.flapBackStrength != flapBackStrength;
}

/// CustomClipper that clips the stationary portion of the page during flip.
class PageFlipClipper extends CustomClipper<Path> {
  /// Creates a [PageFlipClipper] with the given animation state.
  PageFlipClipper({
    /// Normalised flip progress from 0.0 to 1.0.
    required this.progress,

    /// Whether the flip direction is right-to-left.
    required this.isRightToLeft,

    /// Touch offset used to compute the fold angle.
    required this.touchOffset,

    /// True if rendering for a dual spread book
    this.isDoubleSpread = false,

    /// True if we are flipping forward
    this.isForward = true,

    /// Pre-computed geometry (avoids redundant construction per frame).
    this.geo,
  });

  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// True if we are flipping forward
  final bool isForward;

  /// Pre-computed geometry shared with painter (perf optimization).
  final PageFlipGeometry? geo;

  @override
  Path getClip(Size size) {
    // Use pre-computed geo when available (fast path during animation).
    // Falls back to constructing from individual params (backward compatible).
    final g = geo ??
        PageFlipGeometry(
          progress: progress,
          isRightToLeft: isRightToLeft,
          touchOffset: touchOffset,
          size: size,
          isDoubleSpread: isDoubleSpread,
          isForward: isForward,
        );

    if (g.progress <= 0) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    if (g.progress >= 1) {
      return Path();
    }

    return buildStationaryPageClipPath(size, g);
  }

  /// Only reclips when progress or touch offset changes.
  @override
  bool shouldReclip(covariant PageFlipClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.touchOffset != touchOffset ||
      oldClipper.isRightToLeft != isRightToLeft ||
      oldClipper.isDoubleSpread != isDoubleSpread ||
      oldClipper.isForward != isForward;
}

/// CustomClipper that clips the "revealed" portion of the page during flip.
/// Used for Layer 1 (Bottom Layer) to prevent it from showing under the Flap.
class PageFlipOpenClipper extends CustomClipper<Path> {
  /// Creates a [PageFlipOpenClipper] with the given animation state.
  PageFlipOpenClipper({
    /// Normalised flip progress from 0.0 to 1.0.
    required this.progress,

    /// Whether the flip direction is right-to-left.
    required this.isRightToLeft,

    /// Touch offset used to compute the fold angle.
    required this.touchOffset,

    /// True if rendering for a dual spread book
    this.isDoubleSpread = false,

    /// True if we are flipping forward
    this.isForward = true,

    /// Pre-computed geometry (avoids redundant construction per frame).
    this.geo,
  });

  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// True if we are flipping forward
  final bool isForward;

  /// Pre-computed geometry shared with painter (perf optimization).
  final PageFlipGeometry? geo;

  @override
  Path getClip(Size size) {
    // Use pre-computed geo when available (fast path during animation).
    final g = geo ??
        PageFlipGeometry(
          progress: progress,
          isRightToLeft: isRightToLeft,
          touchOffset: touchOffset,
          size: size,
          isDoubleSpread: isDoubleSpread,
          isForward: isForward,
        );

    if (g.progress <= 0 || g.progress >= 1) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    return buildOpenPageClipPath(size, g);
  }

  /// Only reclips when progress or touch offset changes.
  @override
  bool shouldReclip(covariant PageFlipOpenClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.touchOffset != touchOffset ||
      oldClipper.isRightToLeft != isRightToLeft ||
      oldClipper.isDoubleSpread != isDoubleSpread ||
      oldClipper.isForward != isForward;
}
