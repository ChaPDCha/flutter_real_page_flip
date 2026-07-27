import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_constants.dart';
import 'package:real_page_flip/src/effects/page_flip_geometry.dart';

/// Snaps a coordinate to half-pixel grid for consistent [ClipPath] / canvas clip.
double snapClipCoord(double value) => (value * 2).round() / 2;

/// Applies [snapClipCoord] to a point, optionally shifting along [overlapAxis].
///
/// [overlapAxis] defaults to the screen X axis for backwards-compatible tests
/// and helpers. Fold clips pass [PageFlipGeometry.foldNormal] so anti-alias
/// bleed is applied perpendicular to the tilted fold instead of horizontally.
Offset snapClipPoint(
  Offset point, {
  double overlapShift = 0,
  Offset overlapAxis = const Offset(1, 0),
}) =>
    Offset(
      snapClipCoord(point.dx + overlapAxis.dx * overlapShift),
      snapClipCoord(point.dy + overlapAxis.dy * overlapShift),
    );

/// Appends the global fold-line boundary to [path] (caller must [Path.moveTo] first).
///
/// [overlapShift] moves the boundary along [PageFlipGeometry.foldNormal]
/// (stationary layer uses positive bleed; open/revealed layer uses negative
/// bleed so both layers overlap perpendicular to the tilted fold).
void appendFoldLineBoundary(
  Path path,
  PageFlipGeometry geo, {
  double overlapShift = 0,
}) {
  final top = snapClipPoint(
    geo.foldLineTop,
    overlapShift: overlapShift,
    overlapAxis: geo.foldNormal,
  );
  path.lineTo(top.dx, top.dy);

  if (geo.curvatureAmount > 0.001) {
    final control = snapClipPoint(
      geo.foldCurveControl,
      overlapShift: overlapShift,
      overlapAxis: geo.foldNormal,
    );
    final bottom = snapClipPoint(
      geo.foldLineBottom,
      overlapShift: overlapShift,
      overlapAxis: geo.foldNormal,
    );
    path.quadraticBezierTo(control.dx, control.dy, bottom.dx, bottom.dy);
  } else {
    final bottom = snapClipPoint(
      geo.foldLineBottom,
      overlapShift: overlapShift,
      overlapAxis: geo.foldNormal,
    );
    path.lineTo(bottom.dx, bottom.dy);
  }
}

/// Clip path for layer 2 (stationary spread half, left of fold + bleed).
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

/// Maximum visible horizontal offset of the quadratic fold curve.
///
/// The fold path uses a quadratic bezier with straight endpoints and one
/// horizontally shifted control point, so the actual midpoint bulge is half of
/// [PageFlipGeometry.curveOffset]. Treating the control-point shift as the
/// visible bulge makes the crease shadow twice as wide as the paper geometry.
double foldCurveMaxBulge(PageFlipGeometry geo) =>
    geo.curvatureAmount > 0.001 ? geo.curveOffset.abs() * 0.5 : 0.0;

/// Quadratic blend shared by every visible flap boundary.
///
/// The screen-space fold and free-edge paths deliberately extend from `-H` to
/// `2H` so angled turns cannot expose the viewport corners. A visible row must
/// therefore be evaluated in that same extended domain. Keeping this mapping
/// here prevents the content mesh, paper underlay masks, and clip paths from
/// interpreting the same swipe progress as differently curved sheets.
double flapCurveBlendAt(double localY, double height) {
  if (height <= 0) return 0;
  final t = ((localY + height) / (height * 3)).clamp(0.0, 1.0).toDouble();
  return 2 * (1 - t) * t;
}

/// X coordinate on a flap boundary in the shared extended curve domain.
double flapBoundaryCurveXAt({
  required double baseX,
  required double curveOffset,
  required double localY,
  required double height,
}) =>
    baseX - curveOffset * flapCurveBlendAt(localY, height);

/// Local-space x coordinate of the curved fold at [localY].
///
/// This mirrors [appendFoldLineBoundary], which extends the fold endpoints
/// beyond the viewport to avoid clipping artifacts at the top and bottom.
double foldCurveXAt(PageFlipGeometry geo, double localY) {
  if (geo.curvatureAmount <= 0.001) return geo.foldX;

  final height = geo.size.height;
  if (height <= 0) return geo.foldX;

  return flapBoundaryCurveXAt(
    baseX: geo.foldX,
    curveOffset: geo.curveOffset,
    localY: localY,
    height: height,
  );
}

/// Local-space x coordinate of the curved flap free edge at [localY].
///
/// This matches the edge column produced by `buildFlapContentMesh`. Masks and
/// crease shading must use the same curve; otherwise the paper curls but its
/// edge shadow remains a straight strip.
double flapEdgeCurveXAt(PageFlipGeometry geo, double localY) {
  if (geo.curvatureAmount <= 0.001) return geo.freeEdgeX;

  final height = geo.size.height;
  if (height <= 0) return geo.freeEdgeX;

  return flapBoundaryCurveXAt(
    baseX: geo.freeEdgeX,
    curveOffset: geo.curveOffset,
    localY: localY,
    height: height,
  );
}

/// Curved local strip along either the fold crease or lifted free edge.
///
/// The strip extends from the selected boundary into the visible flap. It is
/// used for paper-colour masks and fold darkening so their hard edge follows
/// the same quadratic curve as the actual curled mesh.
Path buildCurvedFlapBoundaryStripPath(
  PageFlipGeometry geo, {
  required bool atFold,
  required double width,
}) {
  final safeWidth = width.clamp(0.0, double.infinity).toDouble();
  final height = geo.size.height;
  if (safeWidth <= 0 || height <= 0) return Path();

  final topY = -height;
  final midY = height / 2;
  final bottomY = height * 2;
  final edgeX = atFold ? geo.foldX : geo.freeEdgeX;
  final inward = atFold
      ? (geo.flapRightOfFold ? 1.0 : -1.0)
      : (geo.flapRightOfFold ? -1.0 : 1.0);
  final innerShift = inward * safeWidth;

  Offset point(double shift, double y) {
    final base = atFold ? foldCurveXAt(geo, y) : flapEdgeCurveXAt(geo, y);
    return Offset(base + shift, y);
  }

  Offset control(double shift) => Offset(
        edgeX - geo.curveOffset + shift,
        midY,
      );

  final outerTop = point(0, topY);
  final path = Path()..moveTo(outerTop.dx, outerTop.dy);

  if (geo.curvatureAmount > 0.001) {
    final outerControl = control(0);
    final outerBottom = point(0, bottomY);
    path.quadraticBezierTo(
      outerControl.dx,
      outerControl.dy,
      outerBottom.dx,
      outerBottom.dy,
    );
  } else {
    final outerBottom = point(0, bottomY);
    path.lineTo(outerBottom.dx, outerBottom.dy);
  }

  final innerBottom = point(innerShift, bottomY);
  path.lineTo(innerBottom.dx, innerBottom.dy);

  if (geo.curvatureAmount > 0.001) {
    final innerControl = control(innerShift);
    final innerTop = point(innerShift, topY);
    path.quadraticBezierTo(
      innerControl.dx,
      innerControl.dy,
      innerTop.dx,
      innerTop.dy,
    );
  } else {
    final innerTop = point(innerShift, topY);
    path.lineTo(innerTop.dx, innerTop.dy);
  }

  path.close();
  return path;
}

/// Local-space shadow band following the same curved fold boundary as the flap.
///
/// [isForward] determines which side of the fold receives the revealed-page
/// shadow. Forward flips reveal to the positive-X side; backward flips reveal
/// to the negative-X side. A small fold-side bleed keeps anti-aliased clip
/// edges covered without making the whole band visually thick.
Path buildCurvedFoldShadowPath(
  PageFlipGeometry geo, {
  required bool isForward,
  required double shadowWidth,
  double foldEdgeBleedPx = kSpineRevealOverlapPx,
}) {
  final height = geo.size.height;
  final topY = -height;
  final midY = height / 2;
  final bottomY = height * 2;
  final shadowSide = isForward ? 1.0 : -1.0;
  final innerShift = -shadowSide * foldEdgeBleedPx;
  final outerShift = shadowSide * shadowWidth;

  Offset point(double shift, double y) => Offset(geo.foldX + shift, y);
  Offset control(double shift) =>
      Offset(geo.foldX - geo.curveOffset + shift, midY);

  final outerTop = point(outerShift, topY);
  final path = Path()..moveTo(outerTop.dx, outerTop.dy);

  if (geo.curvatureAmount > 0.001) {
    final outerControl = control(outerShift);
    final outerBottom = point(outerShift, bottomY);
    path.quadraticBezierTo(
      outerControl.dx,
      outerControl.dy,
      outerBottom.dx,
      outerBottom.dy,
    );
  } else {
    final outerBottom = point(outerShift, bottomY);
    path.lineTo(outerBottom.dx, outerBottom.dy);
  }

  final innerBottom = point(innerShift, bottomY);
  path.lineTo(innerBottom.dx, innerBottom.dy);

  if (geo.curvatureAmount > 0.001) {
    final innerControl = control(innerShift);
    final innerTop = point(innerShift, topY);
    path.quadraticBezierTo(
      innerControl.dx,
      innerControl.dy,
      innerTop.dx,
      innerTop.dy,
    );
  } else {
    final innerTop = point(innerShift, topY);
    path.lineTo(innerTop.dx, innerTop.dy);
  }

  path.close();
  return path;
}

/// Builds one color-interpolated mesh for the complete single-page crease.
///
/// A regular [LinearGradient] is straight in shader space even when its clip
/// path is curved. That leaves the darkest part of the shadow axis-aligned while
/// the paper follows [foldCurveXAt]. This mesh places every opacity column on a
/// translated copy of that same fold curve, so the flap-side shade, crease peak,
/// and revealed-page falloff remain one continuous optical boundary.
List<({double shift, double opacity})> _creaseValleyColumns({
  required PageFlipGeometry geo,
  required double flapSideWidth,
  required double revealedSideWidth,
  required double peakOpacity,
}) {
  final flapSign = geo.flapRightOfFold ? 1.0 : -1.0;
  final revealedSign = -flapSign;
  return <({double shift, double opacity})>[
    (shift: flapSign * flapSideWidth, opacity: 0),
    (shift: flapSign * flapSideWidth * 0.35, opacity: peakOpacity * 0.32),
    (shift: 0, opacity: peakOpacity),
    (
      shift: revealedSign * revealedSideWidth * 0.18,
      opacity: peakOpacity * 0.45,
    ),
    (
      shift: revealedSign * revealedSideWidth * 0.55,
      opacity: peakOpacity * 0.12,
    ),
    (shift: revealedSign * revealedSideWidth, opacity: 0),
  ]..sort((a, b) => a.shift.compareTo(b.shift));
}

/// Vertex positions used by [buildCurvedCreaseValleyMesh].
///
/// Every row contains a vertex on [foldCurveXAt], with all remaining columns
/// kept as parallel translations of that exact curve.
Float32List buildCurvedCreaseValleyPositions(
  PageFlipGeometry geo, {
  required double flapSideWidth,
  required double revealedSideWidth,
  int segments = 12,
}) {
  final safeSegments = math.max(segments, 0);
  final safeFlapWidth = flapSideWidth.clamp(0.0, double.infinity).toDouble();
  final safeRevealedWidth =
      revealedSideWidth.clamp(0.0, double.infinity).toDouble();
  final height = geo.size.height;

  if (safeSegments == 0 ||
      height <= 0 ||
      safeFlapWidth + safeRevealedWidth <= 0) {
    return Float32List(0);
  }

  final columns = _creaseValleyColumns(
    geo: geo,
    flapSideWidth: safeFlapWidth,
    revealedSideWidth: safeRevealedWidth,
    peakOpacity: 1,
  );
  final rows = safeSegments + 1;
  final columnCount = columns.length;
  final positions = Float32List(rows * columnCount * 2);
  final topY = -height;
  final verticalSpan = height * 3;

  for (var row = 0; row < rows; row++) {
    final y = topY + verticalSpan * (row / safeSegments);
    final foldX = foldCurveXAt(geo, y);
    final rowBase = row * columnCount;

    for (var column = 0; column < columnCount; column++) {
      final vertex = rowBase + column;
      positions[vertex * 2] = foldX + columns[column].shift;
      positions[vertex * 2 + 1] = y;
    }
  }

  return positions;
}

ui.Vertices buildCurvedCreaseValleyMesh(
  PageFlipGeometry geo, {
  required double flapSideWidth,
  required double revealedSideWidth,
  required Color color,
  required double peakOpacity,
  int segments = 12,
}) {
  final safeSegments = math.max(segments, 0);
  final safeFlapWidth = flapSideWidth.clamp(0.0, double.infinity).toDouble();
  final safeRevealedWidth =
      revealedSideWidth.clamp(0.0, double.infinity).toDouble();
  final safePeak = peakOpacity.clamp(0.0, 1.0).toDouble();
  final positions = buildCurvedCreaseValleyPositions(
    geo,
    flapSideWidth: safeFlapWidth,
    revealedSideWidth: safeRevealedWidth,
    segments: safeSegments,
  );

  if (positions.isEmpty || safePeak <= 0) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List(0),
      colors: Int32List(0),
    );
  }

  final columns = _creaseValleyColumns(
    geo: geo,
    flapSideWidth: safeFlapWidth,
    revealedSideWidth: safeRevealedWidth,
    peakOpacity: safePeak,
  );
  final columnCount = columns.length;
  final rows = safeSegments + 1;
  final colors = Int32List(rows * columnCount);
  for (var row = 0; row < rows; row++) {
    final rowBase = row * columnCount;
    for (var column = 0; column < columnCount; column++) {
      colors[rowBase + column] =
          color.withValues(alpha: columns[column].opacity).toARGB32();
    }
  }

  final indices = Uint16List(safeSegments * (columnCount - 1) * 6);
  var index = 0;
  for (var row = 0; row < safeSegments; row++) {
    final current = row * columnCount;
    final next = (row + 1) * columnCount;
    for (var column = 0; column < columnCount - 1; column++) {
      indices[index++] = current + column;
      indices[index++] = next + column;
      indices[index++] = current + column + 1;
      indices[index++] = current + column + 1;
      indices[index++] = next + column;
      indices[index++] = next + column + 1;
    }
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    colors: colors,
    indices: indices,
  );
}

/// Local-space contact (ambient-occlusion) shadow just OUTSIDE the lifted free
/// edge, following the same curved flap-edge bezier as the mesh.
///
/// A real lifted page edge is grounded onto the flat sheet beneath it by a
/// thin, soft shadow on the far side of the edge (away from the fold). Drawing
/// this inside the fold transform keeps the band parallel to the tilted edge.
/// The outward direction is derived from [PageFlipGeometry.flapRightOfFold]:
/// the shadow extends toward +X when the flap sits right of the fold, −X else.
Path buildCurvedFreeEdgeShadowPath(
  PageFlipGeometry geo, {
  required double shadowWidth,
  double edgeBleedPx = kSpineRevealOverlapPx,
}) {
  final height = geo.size.height;
  if (height <= 0 || shadowWidth <= 0) return Path();

  final topY = -height;
  final midY = height / 2;
  final bottomY = height * 2;
  // Outward = away from the flap interior (fold). Same side the free edge sits
  // on relative to the fold.
  final outwardSign = geo.flapRightOfFold ? 1.0 : -1.0;
  // Small inward bleed so the band tucks under the flap's anti-aliased edge
  // instead of leaving a hairline gap on the page beneath.
  final innerShift = -outwardSign * edgeBleedPx;
  final outerShift = outwardSign * shadowWidth;

  Offset point(double shift, double y) => Offset(geo.freeEdgeX + shift, y);
  Offset control(double shift) =>
      Offset(geo.freeEdgeX - geo.curveOffset + shift, midY);

  final outerTop = point(outerShift, topY);
  final path = Path()..moveTo(outerTop.dx, outerTop.dy);

  if (geo.curvatureAmount > 0.001) {
    final outerControl = control(outerShift);
    final outerBottom = point(outerShift, bottomY);
    path.quadraticBezierTo(
      outerControl.dx,
      outerControl.dy,
      outerBottom.dx,
      outerBottom.dy,
    );
  } else {
    final outerBottom = point(outerShift, bottomY);
    path.lineTo(outerBottom.dx, outerBottom.dy);
  }

  final innerBottom = point(innerShift, bottomY);
  path.lineTo(innerBottom.dx, innerBottom.dy);

  if (geo.curvatureAmount > 0.001) {
    final innerControl = control(innerShift);
    final innerTop = point(innerShift, topY);
    path.quadraticBezierTo(
      innerControl.dx,
      innerControl.dy,
      innerTop.dx,
      innerTop.dy,
    );
  } else {
    final innerTop = point(innerShift, topY);
    path.lineTo(innerTop.dx, innerTop.dy);
  }

  path.close();
  return path;
}

/// Local-space flap region clip used by `PageFlipPainter` (matches fold seam).
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

/// Local paint bounds for flap overlays that must cover the full screen-space
/// flap clip after rotation.
///
/// The flap clip extends fold/free-edge boundaries above and below the
/// viewport so angled drags do not leave anti-aliased holes at the top or
/// bottom. Paper underlays, fade overlays, masks, and shading need the same
/// vertical bleed; otherwise an extreme upward/downward gesture can expose a
/// narrow unpainted strip between clipped layers.
Rect buildFlapPaintBoundsLocal(
  PageFlipGeometry geo, {
  double? verticalBleed,
  double foldEdgeBleedPx = kSpineRevealOverlapPx,
}) {
  final height = geo.size.height;
  final bleed = verticalBleed ?? (height > 0 ? height : 0.0);
  // The quadratic free edge protrudes beyond the flat flap rectangle by up to
  // half of its control-point offset. Expand both horizontal sides because the
  // sign reverses for backward turns. The screen-space flap path remains the
  // exact visual clip; this conservative local rect only guarantees that the
  // clipped sheet always has an opaque paper underlay.
  final horizontalCoverage = foldCurveMaxBulge(geo) + foldEdgeBleedPx;
  return Rect.fromLTRB(
    geo.flapLeft - horizontalCoverage,
    -bleed,
    geo.flapLeft + geo.flapVisibleWidth + horizontalCoverage,
    height + bleed,
  );
}


/// Screen-space flap region clip used by `PageFlipPainter` BEFORE canvas transform.
///
/// Unlike `buildFlapClipPathLocal` (which operates in transformed local space),
/// this path follows the actual fold line and flap edge in screen space so it
/// exactly matches the clip of Layer 2 (stationary page), eliminating the seam
/// where wrong content shows through.
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
    final foldLineTop = snapClipPoint(
      geo.foldLineTop,
      overlapShift: -foldEdgeBleedPx,
      overlapAxis: geo.foldNormal,
    );
    final foldLineBottom = snapClipPoint(
      geo.foldLineBottom,
      overlapShift: -foldEdgeBleedPx,
      overlapAxis: geo.foldNormal,
    );
    path.moveTo(foldLineTop.dx, foldLineTop.dy);
    path.lineTo(flapEdgeTop.dx, flapEdgeTop.dy);
    if (geo.curvatureAmount > 0.001) {
      final flapControl = snapClipPoint(geo.flapCurveControl);
      path.quadraticBezierTo(
        flapControl.dx,
        flapControl.dy,
        flapEdgeBottom.dx,
        flapEdgeBottom.dy,
      );
    } else {
      path.lineTo(flapEdgeBottom.dx, flapEdgeBottom.dy);
    }
    path.lineTo(foldLineBottom.dx, foldLineBottom.dy);
    if (geo.curvatureAmount > 0.001) {
      final control = snapClipPoint(
        geo.foldCurveControl,
        overlapShift: -foldEdgeBleedPx,
        overlapAxis: geo.foldNormal,
      );
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
