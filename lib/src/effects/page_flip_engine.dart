import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Flap front texture helpers
// ---------------------------------------------------------------------------

/// Returns the source rect within a spread snapshot for the flipping flap front.
///
/// Forward double-spread: right half of the **current** spread (turning page).
/// Backward double-spread: left half of the **current** spread (turning page).
/// Spine reveal in layer 2 shows the adjacent spread half after crossing the spine.
/// Single-page backward flips use paper back only.
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

  if (!isForward) return null;

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
}) {
  // Normalize progress so p always goes 0→1 from flip-start to flip-end.
  // Forward:  p = progress (0→1 at start→completion).
  // Backward: p = progress (1→0 at start→completion) → invert.
  final p = isForward ? progress : (1.0 - progress);

  // Phase 1: brief early visibility → fast hide as fold begins.
  if (p <= fadeOutEnd) {
    if (fadeOutEnd <= 0) return 0.0;
    final t = 1.0 - p / fadeOutEnd;
    return t * t * (3 - 2 * t);
  }

  // Phase 2: mid fold — paper back only (longest phase).
  if (p < revealStart) return 0.0;

  // Phase 3: late settle reveal.
  if (p >= revealEnd) return 1.0;
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
Offset snapClipPoint(Offset point, {double overlapShift = 0}) {
  return Offset(
    snapClipCoord(point.dx + overlapShift),
    snapClipCoord(point.dy),
  );
}

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
  final path = Path()
    ..moveTo(0, 0);
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
  final path = Path()
    ..moveTo(size.width, 0);
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
  final positions = <double>[];
  final texCoords = <double>[];
  final height = size.height;
  final totalCols = columns + 2; // fold + interior + flap edge columns

  // -----------------------------------------------------------------------
  // 1. Build vertex grid [segments+1] × [totalCols].
  //
  // Each row is a horizontal strip. Each column runs from fold (j=0) to
  // flap edge (j=totalCols-1). Interior columns receive an amplified bezier
  // offset so the surface bulges in the middle — the paper looks convex
  // rather than a flat strip connecting two curves.
  //
  //   fold  col1  col2  col3  col4  flap
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row 0 (top)
  //    │╲    │     │     │     │    ╱│
  //    │ ╲   │     │ ╶───→│     │   ╱ │   bulge peak (more left shift)
  //    │  ╲  │     │     │     │  ╱  │
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row N (bottom)
  // -----------------------------------------------------------------------
  final gridX = List.generate(segments + 1, (_) => Float64List(totalCols));
  final gridY = List.generate(segments + 1, (_) => Float64List(totalCols));
  final gridU = List.generate(segments + 1, (_) => Float64List(totalCols));
  final gridV = List.generate(segments + 1, (_) => Float64List(totalCols));

  // Surface bulge factor: how much extra curvature interior columns get.
  // 30% additional bezier offset at the midpoint column creates visible
  // 3D curvature without looking like tightly rolled paper.
  const double kBulgeStrength = 0.30;

  for (int i = 0; i <= segments; i++) {
    final t = i / segments;
    final y = height * t;
    // Vertical quadratic bezier blend: 2(1-t)t — peak at t=0.5, zero at ends.
    final b = 2 * (1 - t) * t;

    for (int j = 0; j < totalCols; j++) {
      final s = j / (totalCols - 1); // 0 at fold, 1 at flap edge

      // Interior columns get amplified bezier offset → surface bulge.
      // sin(s*pi) peaks at s=0.5 and is zero at both edges, so the bulge
      // smoothly blends to the existing fold/flap edge positions.
      final bulgeScale = columns > 0 ? math.sin(s * math.pi) : 0.0;
      final colCurveScale = 1.0 + kBulgeStrength * bulgeScale;
      final colOffset = curveOffset * colCurveScale;

      // Column bezier-fold position at this row.
      final foldAtY = foldX - colOffset * b;
      final flapAtY = flapLeft - colOffset * b;

      // Interpolate X between fold and flap edge for this column.
      gridX[i][j] = foldAtY + (flapAtY - foldAtY) * s;
      gridY[i][j] = y;
      // UV: right→left from srcRect.right (fold) to srcRect.left (flap edge).
      // flipHorizontal for mirrored 2.5D back content on double-spread.
      gridU[i][j] = flipHorizontal
          ? srcRect.left + s * srcRect.width
          : srcRect.right - s * srcRect.width;
      gridV[i][j] = srcRect.top + t * srcRect.height;
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
  // -----------------------------------------------------------------------
  for (int i = 0; i < segments; i++) {
    for (int j = 0; j < totalCols - 1; j++) {
      positions.addAll([
        gridX[i][j], gridY[i][j],
        gridX[i + 1][j], gridY[i + 1][j],
        gridX[i][j + 1], gridY[i][j + 1],
      ]);
      texCoords.addAll([
        gridU[i][j], gridV[i][j],
        gridU[i + 1][j], gridV[i + 1][j],
        gridU[i][j + 1], gridV[i][j + 1],
      ]);

      positions.addAll([
        gridX[i][j + 1], gridY[i][j + 1],
        gridX[i + 1][j], gridY[i + 1][j],
        gridX[i + 1][j + 1], gridY[i + 1][j + 1],
      ]);
      texCoords.addAll([
        gridU[i][j + 1], gridV[i][j + 1],
        gridU[i + 1][j], gridV[i + 1][j],
        gridU[i + 1][j + 1], gridV[i + 1][j + 1],
      ]);
    }
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    Float32List.fromList(positions),
    textureCoordinates: Float32List.fromList(texCoords),
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
/// Use this in [PageFlipLayerView] flip layers. Do **not** pair with
/// [FractionallySizedBox] — that would double horizontal scale and stretch
/// spread snapshots via [BoxFit.fill].
Widget clipFullSpreadHalf({
  required Widget child,
  required Alignment alignment,
}) {
  return ClipRect(
    child: Align(
      alignment: alignment,
      widthFactor: 0.5,
      child: child,
    ),
  );
}

/// Clips [child] to the left or right half when [child] lives in a **half-width**
/// slot (e.g. [Expanded] in a [Row]) and must be expanded to full spread width
/// before clipping — typical host `itemBuilder` layouts.
Widget clipSpreadPageHalf({
  required Widget child,
  required Alignment alignment,
}) {
  return ClipRect(
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
}

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
      filterQuality: FilterQuality.medium,
    ),
  );
}

// ---------------------------------------------------------------------------
// Geometry & rendering constants
// ---------------------------------------------------------------------------

/// Scales the vertical touch offset to the fold rotation angle.
/// Tuned empirically for natural paper-feel rotation.
const double _kAngleScale = 0.3000850509;

/// Base multiplier for visible flap width during foreshortening.
const double _kFlapWidthBase = 1.0000850509;

/// Sine modulation amplitude for flap-width foreshortening.
const double _kFlapWidthModulation = 0.3000850509;

/// Maximum width (px) of the drop shadow cast by the revealed (new) page.
const double _kRevealedShadowWidth = 30.00850509;

/// Maximum width (px) of the shadow on the stationary page edge.
const double _kStationaryShadowWidth = 20.00850509;

/// Animation curve that models real paper page-turning physics.
///
/// Real paper accelerates quickly when pushed (user momentum), then decelerates
/// mid-turn due to air resistance and paper stiffness, before accelerating again
/// near the end as gravity assists the completion. This asymmetric profile
/// produces a natural "whoosh-and-settle" feel.
///
/// Speed profile:
///   • 0% → 30% of time:  reaches ~50% progress (fast push)
///   • 30% → 70% of time: reaches ~80% progress (air resistance plateau)
///   • 70% → 100% of time: reaches 100% progress (gravity settle)
///
/// Use for [AnimationController.animateTo] in both forward completion and
/// snap-back directions — fast initial retreat avoids input lag perception.
class PaperFlipCurve extends Cubic {
  /// Creates a paper physics curve (C∞ smooth cubic bezier).
  ///
  /// Control points tuned for paper-like acceleration:
  ///   • Early push: quick initial acceleration (small a=0.05).
  ///   • Mid plateau: air-resistance deceleration (b=0.7 pulls right).
  ///   • Late settle: gravity-assisted completion (c=0.1, d=1.0).
  const PaperFlipCurve() : super(0.05, 0.7, 0.1, 1.0);
}

/// Smooth tap-flip curve gentler than [PaperFlipCurve] for short programmatic
/// flips where the user is not providing momentum via drag.
class TapFlipCurve extends Curve {
  /// Creates a tap flip curve.
  const TapFlipCurve();

  @override
  double transformInternal(double t) {
    // Softer bell: ease-in-out-quart profile.
    // Slower start (no user momentum), smooth mid, gentle settle.
    return t < 0.5
        ? 4.0 * t * t * t
        : 1.0 - math.pow(-2.0 * t + 2.0, 3).toDouble() / 2.0;
  }
}

/// Shared geometry calculations for PageFlipClipper and PageFlipPainter.
/// This ensures both use IDENTICAL coordinate calculations.
class PageFlipGeometry {
  /// Creates a [PageFlipGeometry] instance that computes all derived
  /// fold, flap, and shadow values from the input parameters.
  PageFlipGeometry({
    /// Normalised flip progress from 0.0 to 1.0.
    required this.progress,

    /// Whether the flip direction is right-to-left.
    required this.isRightToLeft,

    /// Touch offset used to compute the fold angle.
    required this.touchOffset,

    /// Size of the widget area being flipped.
    required this.size,
    
    /// True if the layout is double-spread with a central spine
    this.isDoubleSpread = false,

    /// True if we are flipping forward (right-to-left), false if backward
    this.isForward = true,
  }) {
    final width = size.width;
    final height = size.height;
    spineX = isDoubleSpread ? width / 2 : 0.0;

    final pageWidth = isDoubleSpread ? width / 2 : width;

    // ── Fold line position ──────────────────────────────────────────────────
    // Forward:  right page peels right→left. foldX moves width → spineX (or 0).
    // Backward: left page peels left→right.  foldX moves 0 → pageWidth.
    if (isForward) {
      foldX = width - (pageWidth * progress);
    } else {
      foldX = pageWidth * progress;
    }

    // ── Rotation angle ──────────────────────────────────────────────────────
    // Asymmetric profile: fast rise (~40% of flip), slower settle (~60%).
    final angleT = math.pow(progress, 0.82).toDouble();
    final angleProfile = math.sin(angleT * math.pi);
    final baseAngle = (touchOffset.dy / height - 0.5) *
        _kAngleScale *
        angleProfile;

    // Limit angle so the fold line stays within page bounds.
    // Forward: flap is left of foldX, bounded by stationary side (foldX-spineX)
    //          and flap side (width-foldX).
    // Backward: flap is right of foldX, bounded by revealed side (foldX)
    //           and flap side (pageWidth-foldX).
    final flapSideWidth = isForward ? (width - foldX) : foldX;
    final revealedSideWidth = isForward
        ? (foldX - spineX).clamp(0.0, double.infinity)
        : (pageWidth - foldX).clamp(0.0, double.infinity);
    final limitFlap = math.atan2(flapSideWidth, height / 2);
    final limitRevealed = math.atan2(revealedSideWidth, height / 2);
    final absLimit =
        math.max(0.0, math.min(limitFlap, limitRevealed));

    // Invert angle for backward so that touching the top half lifts the flap
    // top regardless of flip direction: with the flap on opposite sides of
    // foldX, the rotation must reverse to keep the visual response consistent.
    final rawAngle = isForward ? baseAngle : -baseAngle;
    angle = rawAngle.clamp(-absLimit, absLimit);

    // Transformation matrix: hinge at foldX.
    transform = Matrix4.identity()
      ..multiply(Matrix4.translationValues(foldX, height / 2, 0))
      ..rotateZ(-angle)
      ..multiply(Matrix4.translationValues(-foldX, -height / 2, 0));

    // ── Fold line endpoints ─────────────────────────────────────────────────
    foldLineTop = MatrixUtils.transformPoint(transform, Offset(foldX, -height));
    foldLineBottom = MatrixUtils.transformPoint(
      transform,
      Offset(foldX, height * 2),
    );

    // ── Shadow intensity ────────────────────────────────────────────────────
    shadowIntensity = math.sin(progress * math.pi);

    // ── Flap dimensions ─────────────────────────────────────────────────────
    // Forward:  flap extends LEFT  from foldX. flapMaterialWidth = width - foldX.
    // Backward: flap extends RIGHT from foldX. flapMaterialWidth = foldX (peeled from 0).
    final flapMaterialWidth =
        isForward ? (width - foldX) : foldX;

    flapVisibleWidth = flapMaterialWidth *
        (_kFlapWidthBase - _kFlapWidthModulation * math.sin(progress * math.pi));

    // Free edge of the flap:
    // Forward:  flapLeft (left of foldX).  Backward: flapRight (right of foldX).
    // We store in flapLeft for backward compatibility of the field name.
    flapLeft = isForward ? foldX - flapVisibleWidth : foldX + flapVisibleWidth;

    // Flap edge endpoints
    flapEdgeTop = MatrixUtils.transformPoint(
      transform,
      Offset(flapLeft, -height),
    );
    flapEdgeBottom = MatrixUtils.transformPoint(
      transform,
      Offset(flapLeft, height * 2),
    );

    // ── Fold curvature ──────────────────────────────────────────────────────
    // Bezier control offset creates subtle paper curl. Peak at mid-flip.
    // Direction: forward = positive (fold moves left), backward = negative.
    curvatureAmount = math.sin(progress * math.pi);
    final curveDirection = isForward ? 1.0 : -1.0;
    curveOffset = curvatureAmount * pageWidth * 0.04 * curveDirection;
    // Control point offset direction:
    // Forward: foldX - curveOffset (control moves left, matching flap direction).
    // Backward: foldX - curveOffset (curveOffset is negative → control moves right,
    //           matching flap direction the other way).
    foldCurveControl = MatrixUtils.transformPoint(
      transform,
      Offset(foldX - curveOffset, height / 2),
    );
    // Flap edge control curve — matches the free edge direction.
    flapCurveControl = MatrixUtils.transformPoint(
      transform,
      Offset(flapLeft - curveOffset, height / 2),
    );
  }
  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// Size of the widget area being flipped.
  final Size size;
  
  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// True if we are flipping forward.
  final bool isForward;

  /// X-coordinate of the paper fold hinge limit (Spine)
  late final double spineX;

  /// X-coordinate of the paper fold hinge.
  late final double foldX;

  /// Fold rotation angle in radians.
  late final double angle;

  /// Transformation matrix for the flipping flap.
  late final Matrix4 transform;

  /// Top endpoint of the fold line (extended for clean clipping).
  late final Offset foldLineTop;

  /// Bottom endpoint of the fold line (extended for clean clipping).
  late final Offset foldLineBottom;

  /// Shadow intensity (0.0 to 1.0), peaking mid-animation.
  late final double shadowIntensity;

  /// Visible width of the flap after foreshortening.
  late final double flapVisibleWidth;

  /// Left edge X-coordinate of the flap.
  late final double flapLeft;

  /// Top endpoint of the flap edge.
  late final Offset flapEdgeTop;

  /// Bottom endpoint of the flap edge.
  late final Offset flapEdgeBottom;

  /// Normalised amount of 2D curvature applied (0.0 to 1.0).
  late final double curvatureAmount;

  /// Local space horizontal offset for the bezier control points.
  late final double curveOffset;

  /// Bezier control point for the curved fold line in global space.
  late final Offset foldCurveControl;

  /// Bezier control point for the curved flap edge in global space.
  late final Offset flapCurveControl;
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
  // Degenerate geometry: flap is too narrow to render.
  // Forward:  flapLeft (free edge) is at or right of foldX → flapVisibleWidth ≤ 0.
  // Backward: flapLeft (free edge) is at or left  of foldX → flapVisibleWidth ≤ 0.
  if (geo.isForward) {
    if (geo.flapLeft >= geo.foldX - 0.5) return Path();
  } else {
    if (geo.flapLeft <= geo.foldX + 0.5) return Path();
  }

  final height = geo.size.height;
  final flapEdgeTop = snapClipPoint(geo.flapEdgeTop);
  final flapEdgeBottom = snapClipPoint(geo.flapEdgeBottom);

  final path = Path();
  path.moveTo(flapEdgeTop.dx, flapEdgeTop.dy);

  // Right edge: follows the fold line (with bleed), matching Layer 2's clip.
  appendFoldLineBoundary(path, geo, overlapShift: foldEdgeBleedPx);

  // Bottom edge: from fold line bottom to flap edge bottom.
  path.lineTo(flapEdgeBottom.dx, flapEdgeBottom.dy);

  // Left edge: flap's free edge (follows the curvature).
  if (geo.curvatureAmount > 0.001) {
    final control = snapClipPoint(geo.flapCurveControl);
    path.quadraticBezierTo(
      control.dx, control.dy,
      flapEdgeTop.dx, flapEdgeTop.dy,
    );
  }
  path.close();
  return path;
}

/// CustomPainter that renders the flipping page flap with shadow and highlight effects.
/// Computes an overall flap opacity multiplier based on flip [progress] for thin-paper
/// and end-reveal effects.
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
}) {
  // Normalize so p always goes 0→1 from start to end of the flip.
  // Forward:  p = progress (0→1)
  // Backward: p = 1 - progress (1→0) → (0→1)
  final p = isForward ? progress : (1.0 - progress);

  if (p <= 0 || p >= 1) return 1.0;
  if (thinPaperStrength <= 0 && endRevealStrength <= 0) return 1.0;

  // Thin paper: sin(p * π) peaks at p = 0.5 (mid-flip).
  final thinFactor = math.sin(p * math.pi) * thinPaperStrength;

  // End reveal: smoothstep from [endRevealStart] to 1.0.
  final revealT = ((p - endRevealStart) / (1.0 - endRevealStart)).clamp(0.0, 1.0);
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

    /// True if rendering for a dual spread book
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
  });

  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// The color of the paper back (flipping page's back side).
  final Color paperBackColor;
  
  /// True if rendering for a dual spread book

  /// How much the paper appears translucent at mid-flip (0.0–1.0).
  final double thinPaperStrength;

  /// How much the next page content shows through at end of flip (0.0–1.0).
  final double endRevealStrength;

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

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) {
      return;
    }

    // Use pre-computed geo when available; otherwise construct here
    // (backward compatible when geo is not passed).
    final g = geo ?? PageFlipGeometry(
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
    final localFlapLeft = g.isForward ? g.flapLeft : g.foldX;
    final flapRect = Rect.fromLTWH(
      localFlapLeft,
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

    );

    final needsLayer = flapAlpha < 0.995;

    if (needsLayer) {

      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: flapAlpha));

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
      final backMesh = buildFlapContentMesh(
        size: size,
        foldX: g.foldX,
        flapLeft: g.flapLeft,
        curveOffset: g.curveOffset,
        srcRect: flapBackSrcRect!,
        segments: 16,
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
            Matrix4.identity().storage,
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

    final hasFlapTexture =
        flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final contentReveal = flapFrontContentRevealOpacity(
        progress,
        fadeOutEnd: flapContentFadeOutEnd,
        revealStart: flapContentRevealStart,
        revealEnd: flapContentRevealEnd,
        isForward: isForward,
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
          final mesh = buildFlapContentMesh(
            size: size,
            foldX: g.foldX,
            flapLeft: g.flapLeft,
            curveOffset: g.curveOffset,
            srcRect: srcRect,
            segments: 16,
          );
          canvas.drawVertices(
            mesh,
            BlendMode.srcOver,
            Paint()
              ..shader = ui.ImageShader(
                flapFrontImage!,
                ui.TileMode.clamp,
                ui.TileMode.clamp,
                Matrix4.identity().storage,
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
    //
    // The flap extends LEFT from foldX, so right = fold hinge, left = free edge.
    final bendStrength = g.shadowIntensity; // 0–1, peaks mid-flip
    if (bendStrength > 0.005) {
      // Gentle centre highlight (catches light on the bulge).
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: g.isForward ? Alignment.centerRight : Alignment.centerLeft,
            end: g.isForward ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.08 * bendStrength),
              Colors.white.withValues(alpha: 0.12 * bendStrength),
              Colors.white.withValues(alpha: 0.08 * bendStrength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.50, 0.75, 1.0],
          ).createShader(flapRect),
      );

      // Subtle fold-edge darkening.
      final foldShadow = (isPaperDark ? 0.10 : 0.15) * bendStrength;
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            begin: g.isForward ? Alignment.centerRight : Alignment.centerLeft,
            end: g.isForward ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: foldShadow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25],
          ).createShader(flapRect),
      );
    }

    // Edge-fade: mask partial-text artifacts at the flap's free edge (flapLeft).
    // A ~8 px gradient from paperBackColor → transparent hides stray character
    // fragments at the mesh boundary without affecting visible flap content.
    const double edgeFadeWidth = 8.0;
    final localEdgeLeft = g.isForward ? g.flapLeft : g.flapLeft - edgeFadeWidth;
    final edgeFadeRect = Rect.fromLTWH(
      localEdgeLeft, 0, edgeFadeWidth, size.height,
    );
    canvas.drawRect(
      edgeFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: g.isForward ? Alignment.centerLeft : Alignment.centerRight,
          end: g.isForward ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            paperBackColor.withValues(alpha: 1.0),
            Colors.transparent,
          ],
        ).createShader(edgeFadeRect),
    );

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    // As the flap narrows near the fold line, texture pixels compress and
    // create visible fragments. This narrow gradient from paperBackColor →
    // transparent softens the fold boundary edge.
    const double foldFadeWidth = 6.0;
    final localFoldLeft = g.isForward ? g.foldX - foldFadeWidth : g.foldX;
    final foldFadeRect = Rect.fromLTWH(
      localFoldLeft, 0, foldFadeWidth, size.height,
    );
    canvas.drawRect(
      foldFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: g.isForward ? Alignment.centerRight : Alignment.centerLeft,
          end: g.isForward ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            paperBackColor.withValues(alpha: 1.0),
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
      canvas.restore();
    }
  }

  @override
  /// Only repaints when animation-critical values change.
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
    final g = geo ?? PageFlipGeometry(
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

  @override
  /// Only reclips when progress or touch offset changes.
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
    final g = geo ?? PageFlipGeometry(
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

  @override
  /// Only reclips when progress or touch offset changes.
  bool shouldReclip(covariant PageFlipOpenClipper oldClipper) =>
      oldClipper.progress != progress ||
      oldClipper.touchOffset != touchOffset ||
      oldClipper.isRightToLeft != isRightToLeft ||
      oldClipper.isDoubleSpread != isDoubleSpread ||
      oldClipper.isForward != isForward;
}

/// Shared horizontal-vs-vertical arbitration for page-flip drags.
class PageFlipGestureArbitration {
  PageFlipGestureArbitration._();

  /// Touch slop derived from [sensitivity] (0.0–1.0).
  static double checkSlopForSensitivity(double sensitivity) =>
      18.0 - (17.0 * sensitivity);

  /// True when accumulated movement is predominantly vertical (text scroll / selection).
  static bool shouldYieldToContent({
    required double totalDx,
    required double totalDy,
    required double sensitivity,
  }) {
    final checkSlop = checkSlopForSensitivity(sensitivity);
    return totalDy.abs() > checkSlop && totalDy.abs() > totalDx.abs() * 1.2;
  }

  /// True when accumulated movement should start a page-flip drag.
  static bool shouldAcceptFlipDrag({
    required double totalDx,
    required double totalDy,
    required double sensitivity,
  }) {
    if (shouldYieldToContent(
      totalDx: totalDx,
      totalDy: totalDy,
      sensitivity: sensitivity,
    )) {
      return false;
    }

    final checkSlop = checkSlopForSensitivity(sensitivity);

    if (totalDx.abs() > checkSlop) {
      if (totalDx.abs() * 2.5 > totalDy.abs()) {
        return true;
      }
    }

    return false;
  }
}

/// A custom HorizontalDragGestureRecognizer that allows for more natural thumb arcs
/// by having a configurable sensitivity and allowing a certain amount of vertical movement.
class PageFlipGestureRecognizer extends HorizontalDragGestureRecognizer {
  /// Creates a [PageFlipGestureRecognizer] with the given sensitivity.
  PageFlipGestureRecognizer({
    super.debugOwner,
    /// Sensitivity of the gesture recognizer (0.0 to 1.0).
    /// Lower values require more horizontal movement to trigger a flip.
    this.sensitivity = 0.5,
  });

  /// Sensitivity of the gesture recognizer (0.0 to 1.0).
  final double sensitivity;
  double _totalDx = 0;
  double _totalDy = 0;
  bool _flipArenaAccepted = false;

  @override
  /// Resets accumulated deltas when a new pointer is added.
  void addAllowedPointer(PointerDownEvent event) {
    _flipArenaAccepted = false;
    super.addAllowedPointer(event);
    _totalDx = 0.0;
    _totalDy = 0.0;
  }

  @override
  void rejectGesture(int pointer) {
    _flipArenaAccepted = false;
    super.rejectGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _totalDx += event.delta.dx;
      _totalDy += event.delta.dy;
      _acceptFlipArenaWhenReady();
    }
    super.handleEvent(event);
  }

  /// Eagerly wins the arena for horizontal page-flip intent only.
  ///
  /// Vertical/content gestures are not rejected here; [hasSufficientGlobalDistanceToAccept]
  /// stays false so [SelectableText] and scrollables can win instead.
  void _acceptFlipArenaWhenReady() {
    if (_flipArenaAccepted) return;

    if (PageFlipGestureArbitration.shouldAcceptFlipDrag(
      totalDx: _totalDx,
      totalDy: _totalDy,
      sensitivity: sensitivity,
    )) {
      _flipArenaAccepted = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return PageFlipGestureArbitration.shouldAcceptFlipDrag(
      totalDx: _totalDx,
      totalDy: _totalDy,
      sensitivity: sensitivity,
    );
  }
}
