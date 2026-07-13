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
part 'page_flip_painter.dart';
part 'page_flip_clippers.dart';

// ---------------------------------------------------------------------------
// Flap front texture helpers
// ---------------------------------------------------------------------------

/// Returns the source rect within a spread snapshot for the flipping flap front.
///
/// Double-spread maps the physically exposed verso strip from the adjacent
/// spread. Forward uses a left-anchored strip from the next spread's left page;
/// backward uses a right-anchored strip from the previous spread's right page.
/// Single-page (both directions): full page rect — the current page wraps onto
/// the flap so content is visible during the turn.
Rect? flapFrontSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
  double? floatProgress,
}) {
  if (isDoubleSpread) {
    final halfWidth = imageSize.width / 2;
    final p = (floatProgress ?? (isForward ? 1.0 : 0.0)).clamp(0.0, 1.0);
    final materialFraction = isForward ? p : 1.0 - p;
    final stripWidth = halfWidth * materialFraction;
    if (isForward) {
      return Rect.fromLTWH(0, 0, stripWidth, imageSize.height);
    }
    return Rect.fromLTWH(
      imageSize.width - stripWidth,
      0,
      stripWidth,
      imageSize.height,
    );
  }

  // Single-page: when [floatProgress] is supplied, map only the LIFTED strip
  // (the page's right portion of width floatProgress·pageWidth) onto the flap.
  // This keeps the crease continuous with the page beneath and preserves the
  // text's horizontal scale, instead of crushing the whole page into the
  // narrowing flap (the "over-compressed back side" artifact). The mesh is
  // drawn with flipHorizontal so this right-anchored strip reads correctly as
  // the folded-over paper.
  if (floatProgress != null) {
    return singlePagePeeledStripRect(imageSize, floatProgress);
  }

  return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
}

/// Right-anchored source strip for the single-page flap at [floatProgress].
///
/// Width grows with the lifted material: `floatProgress · width`, anchored at
/// the page's right edge so the crease (fold) edge stays continuous with the
/// stationary page and the free edge reveals the page's right border.
@visibleForTesting
Rect singlePagePeeledStripRect(Size imageSize, double floatProgress) {
  final p = floatProgress.clamp(0.0, 1.0);
  final stripWidth = imageSize.width * p;
  return Rect.fromLTWH(
    imageSize.width - stripWidth,
    0,
    stripWidth,
    imageSize.height,
  );
}

/// Legacy back-content helper. The double-spread flap front now directly maps
/// the real verso strip, so a second mirrored ghost texture is never needed.
Rect? flapBackSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
}) =>
    null;

/// Returns the source rect within a spread snapshot for settle-phase flap front content.
///
/// During the settle phase (progress 0.85-0.95), the flap shows the **destination**
/// page instead of the page being peeled:
/// - Forward double-spread: LEFT half of the NEXT spread (the page appearing
///   on the right side of the viewport).
/// - Backward double-spread: RIGHT half of the PREVIOUS spread (the page appearing
///   on the left side of the viewport).
/// - Single-page (both directions): unchanged full-page source rect.
Rect? flapFrontSettleSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
  double? floatProgress,
}) {
  if (isDoubleSpread) {
    return flapFrontSourceRect(
      imageSize: imageSize,
      isDoubleSpread: true,
      isForward: isForward,
      floatProgress: floatProgress,
    );
  }

  // Single-page settle phase reuses the same peeled-strip mapping as the front
  // so the page does not "snap" scale between the peel and settle phases.
  if (floatProgress != null) {
    return singlePagePeeledStripRect(imageSize, floatProgress);
  }

  return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
}

/// Peak opacity of the free-edge / fold texture masks (the narrow paper-colour
/// gradients that hide crushed mesh fragments at the flap boundaries).
///
/// On LIGHT paper the mask is paper-over-paper and therefore invisible, so it
/// runs at full opacity to fully hide the crushed edge. On DARK paper (e.g. the
/// pure-black theme) a full-opacity paper strip wipes the light text into a
/// hard vertical "dark band at the paper edge"; holding it below full opacity
/// lets the text bleed through faintly so the edge reads as a soft transition.
@visibleForTesting
double edgeMaskPeakOpacity({required bool isPaperDark}) =>
    isPaperDark ? 0.7 : 1.0;

@visibleForTesting
double edgeMaskWidth({
  required bool isPaperDark,
  double devicePixelRatio = 1.0,
}) =>
    (isPaperDark ? 5.0 : 8.0) * (devicePixelRatio >= 2.0 ? 1.25 : 1.0);

/// Width (px) of the fold-crease texture mask. See [edgeMaskWidth].
@visibleForTesting
double foldMaskWidth({
  required bool isPaperDark,
  double devicePixelRatio = 1.0,
}) =>
    (isPaperDark ? 4.0 : 6.0) * (devicePixelRatio >= 2.0 ? 1.25 : 1.0);

/// Tint of the soft centre highlight that catches light on the curling paper.
///
/// `isPaperDark` selects between dark and light paper surfaces: dark paper gets
/// a faint cool ambient tint so near-black stock reads as a real surface; light
/// paper gets a warm paper-white sheen.
@visibleForTesting
Color flapHighlightTone({required bool isPaperDark}) => isPaperDark
    ? const Color(0xFFE8E8F0) // neutral off-white with minimal blue
    : const Color(0xFFFFF4E0); // warm paper white

/// Base peak alpha of the centre highlight (before shadow-intensity scaling).
///
/// Kept intentionally tiny — thin Bible paper is matte, so a strong specular
/// streak would read as glass/plastic. Dark paper is dimmer still.
@visibleForTesting
double flapHighlightPeakBase({required bool isPaperDark}) =>
    isPaperDark ? 0.07 : 0.10;

/// Base mid-band alpha of the centre highlight (before shadow-intensity).
@visibleForTesting
double flapHighlightMidBase({required bool isPaperDark}) =>
    isPaperDark ? 0.04 : 0.06;

/// How far the free-edge contact shadow lengthens as the flap lifts.
///
/// The lifted edge of a turning leaf throws a longer, softer shadow the higher
/// it rises, so the painted band width is scaled by `1 + gain·shadowIntensity`.
/// The gain is the primary "this leaf is lifted off the page" cue and is scoped
/// to double-spread — the requested mode — so single-page keeps its separately
/// tuned tight grounding shadow (`gain == 0`, band width unchanged). Within
/// double-spread the HIGH profile earns the full soft penumbra (best 2.5D)
/// while the lean default MEDIUM still gets a modest lift so a two-page turn
/// reads as genuinely raised rather than a flat sticker.
@visibleForTesting
double freeEdgeContactLiftGain({
  required DevicePerformanceProfile profile,
  required bool isDoubleSpread,
}) {
  if (!isDoubleSpread) return 0;
  return profile == DevicePerformanceProfile.high ? 1.3 : 0.55;
}

/// Direction-normalized progress used by the flap's phased content effects.
///
/// Double-spread backward flips animate geometry in reverse, so paint-time
/// progress runs 1 -> 0 while the user gesture advances 0 -> 1. Normalize it
/// once and share the result between [PageFlipPainter] and opacity helpers so
/// phase decisions stay consistent across the render pipeline.
double normalizedFlapProgress(
  double progress, {
  required bool isForward,
}) =>
    isForward ? progress : (1.0 - progress);

/// Returns true once the flap may use destination/settle content.
bool isFlapSettlePhase(
  double progress, {
  required bool isForward,
  double revealStart = 0.85,
}) =>
    normalizedFlapProgress(progress, isForward: isForward) >= revealStart;

/// Opacity of flap-front page content (0 = paper back only, 1 = full texture).
///
/// Three-phase curve to hide distorted text during the bend:
/// 1. Early drag (0 → [fadeOutEnd]): brief visibility, fast fade-out.
/// 2. Mid fold ([fadeOutEnd] → [revealStart]): paper back only.
/// 3. Late settle ([revealStart] → [revealEnd]): gentle content reveal.
double flapFrontContentRevealOpacity(
  double progress, {
  double fadeOutEnd = 0.20,
  double revealStart = 0.85,
  double revealEnd = 0.95,
  bool isForward = true,
  bool isDoubleSpread = false,
  bool keepSinglePageContentVisible = true,
  double doubleSpreadMidFoldBleed = 0.0,
}) {
  // Double-spread maps the actual verso, so it stays fully visible throughout.
  if (isDoubleSpread) return 1;

  // Single-page mode: pages are single-sided, so the flipping page shows its
  // own content curling with the paper for the entire turn only when the
  // high-fidelity path opts into it. Medium/low profiles intentionally use the
  // same paper-back reveal curve as double-spread so the back-facing flap stays
  // blank during the main fold and avoids extra mesh work.
  if (!isDoubleSpread && keepSinglePageContentVisible) return 1;

  // Normalize progress so p always goes 0→1 from flip-start to flip-end.
  final p = normalizedFlapProgress(progress, isForward: isForward);
  final bleed = isDoubleSpread ? doubleSpreadMidFoldBleed.clamp(0.0, 1.0) : 0.0;

  // Double-spread two-sided paper model below:
  // Phase 1: brief early visibility → fast hide to bleed floor as fold begins.
  if (p <= fadeOutEnd) {
    if (fadeOutEnd <= 0) return bleed;
    final t = 1.0 - p / fadeOutEnd;
    final earlyFade = t * t * (3 - 2 * t);
    return bleed + (1.0 - bleed) * earlyFade;
  }

  // Phase 2: mid fold — bleed floor (subtle thin-paper translucency).
  if (p < revealStart) return bleed;

  // Phase 3: late settle reveal from bleed floor up to 1.0.
  if (p >= revealEnd) return 1;
  final t = (p - revealStart) / (revealEnd - revealStart);
  final smoothed = t * t * (3 - 2 * t);
  return bleed + (1.0 - bleed) * smoothed;
}

/// Opacity of the stationary middle layer in single-page mode.
///
/// The middle layer holds the page that sits *under* the flap on the
/// stationary side of the fold:
/// - **Forward**: the current (source) page. It fades out during the settle
///   phase ([revealStart] → [revealEnd]) so the flap's destination content
///   takes over without a double-exposed seam.
/// - **Backward**: the incoming previous page. It MUST stay fully opaque for
///   the whole turn because it covers the region to the LEFT of the fold as
///   the page rolls back. [floatProgress] for a backward flip starts near 1.0,
///   so applying the forward fade curve there forced the middle to opacity 0
///   on the first frames and exposed the host background (black scaffold) in a
///   thin strip at the binding edge — the "black flash on previous-page flip"
///   bug. Backward therefore never fades.
double middleLayerOpacity(
  double floatProgress, {
  required bool isForward,
  double revealStart = 0.85,
  double revealEnd = 0.95,
}) {
  if (!isForward) return 1;
  if (floatProgress >= revealEnd) return 0;
  if (floatProgress < revealStart) return 1;
  final divisor = revealEnd - revealStart;
  if (divisor <= 0.001) return 0;
  final t = (floatProgress - revealStart) / divisor;
  return 1.0 - t * t * (3 - 2 * t);
}

/// Dim multiplier for the single-page thin-paper bleed-through overlay.
///
/// Host apps may dim the peeled page's own content toward the paper colour while
/// it is the back-facing side, so the reverse text only bleeds through faintly
/// (controlled by [backOpacity], e.g. 0.35). As the page settles flat it
/// becomes the crisp incoming/destination page, so the dim must relax back to
/// 1.0 (no overlay) across the settle window [[revealStart], [revealEnd]].
///
/// The factor is **continuous**: it holds [backOpacity] through the peel and
/// eases up to 1.0 across the settle window. The previous implementation
/// gated the overlay on a hard `isSettlePhase` boolean, so the overlay's alpha
/// jumped in a single frame at [revealStart] — a visible flicker ("the opaque
/// paper layer disappears midway") at the binding edge near the end of a swipe.
///
/// [normalizedProgress] is direction-normalized (0 = start of fold, 1 = end),
/// matching the painter's `normalizedProgress`. Returns 1.0 (no dim) when
/// [backOpacity] is >= 1.0.
@visibleForTesting
double singlePageBackDim(
  double normalizedProgress, {
  required double backOpacity,
  double revealStart = 0.85,
  double revealEnd = 0.95,
}) {
  if (backOpacity >= 1.0) return 1;
  if (normalizedProgress >= revealEnd) return 1;
  if (normalizedProgress <= revealStart) return backOpacity;
  final divisor = revealEnd - revealStart;
  if (divisor <= 0.001) return 1;
  final t = ((normalizedProgress - revealStart) / divisor).clamp(0.0, 1.0);
  final eased = t * t * (3 - 2 * t);
  return backOpacity + (1.0 - backOpacity) * eased;
}

/// Shared progress epsilon below which the flip is visually invisible.
///
/// [PageFlipPainter], [PageFlipClipper], and [PageFlipOpenClipper] all use
/// this as their early-return / full-rect guard so there is no frame gap
/// where clippers clip but the painter does not paint (or vice-versa).
const double kFlipProgressEpsilon = 0.001;

/// Sub-pixel overlap (px) at layer seams (fold line, flap edge, spine reveal).
///
/// All clippers and [PageFlipPainter] use this value so [ClipPath] and canvas
/// clip boundaries stay aligned and hairline gaps do not appear.
const double kSpineRevealOverlapPx = 1.5;

/// Snaps a coordinate to half-pixel grid for consistent [ClipPath] / canvas clip.
@visibleForTesting
double snapClipCoord(double value) => (value * 2).round() / 2;

/// Applies [snapClipCoord] to a point, optionally shifting along [overlapAxis].
///
/// [overlapAxis] defaults to the screen X axis for backwards-compatible tests
/// and helpers. Fold clips pass [PageFlipGeometry.foldNormal] so anti-alias
/// bleed is applied perpendicular to the tilted fold instead of horizontally.
@visibleForTesting
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
@visibleForTesting
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

/// Maximum visible horizontal offset of the quadratic fold curve.
///
/// The fold path uses a quadratic bezier with straight endpoints and one
/// horizontally shifted control point, so the actual midpoint bulge is half of
/// [PageFlipGeometry.curveOffset]. Treating the control-point shift as the
/// visible bulge makes the crease shadow twice as wide as the paper geometry.
@visibleForTesting
double foldCurveMaxBulge(PageFlipGeometry geo) =>
    geo.curvatureAmount > 0.001 ? geo.curveOffset.abs() * 0.5 : 0.0;

/// Quadratic blend shared by every visible flap boundary.
///
/// The screen-space fold and free-edge paths deliberately extend from `-H` to
/// `2H` so angled turns cannot expose the viewport corners. A visible row must
/// therefore be evaluated in that same extended domain. Keeping this mapping
/// here prevents the content mesh, paper underlay masks, and clip paths from
/// interpreting the same swipe progress as differently curved sheets.
@visibleForTesting
double flapCurveBlendAt(double localY, double height) {
  if (height <= 0) return 0;
  final t = ((localY + height) / (height * 3)).clamp(0.0, 1.0).toDouble();
  return 2 * (1 - t) * t;
}

/// X coordinate on a flap boundary in the shared extended curve domain.
@visibleForTesting
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
@visibleForTesting
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
/// This matches the edge column produced by [buildFlapContentMesh]. Masks and
/// crease shading must use the same curve; otherwise the paper curls but its
/// edge shadow remains a straight strip.
@visibleForTesting
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
@visibleForTesting
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
@visibleForTesting
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
@visibleForTesting
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

@visibleForTesting
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
@visibleForTesting
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

/// Local paint bounds for flap overlays that must cover the full screen-space
/// flap clip after rotation.
///
/// The flap clip extends fold/free-edge boundaries above and below the
/// viewport so angled drags do not leave anti-aliased holes at the top or
/// bottom. Paper underlays, fade overlays, masks, and shading need the same
/// vertical bleed; otherwise an extreme upward/downward gesture can expose a
/// narrow unpainted strip between clipped layers.
@visibleForTesting
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

@visibleForTesting
({int segments, int columns}) flapMeshDensityForPerformance(
  DevicePerformanceProfile profile,
) =>
    switch (profile) {
      DevicePerformanceProfile.low => (segments: 8, columns: 1),
      DevicePerformanceProfile.medium => (segments: 12, columns: 2),
      DevicePerformanceProfile.high => (segments: 16, columns: 4),
    };

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
/// Without this bulge the surface is a flat ruled plane between two curves -
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
  final safeSegments = math.max(segments, 0);
  final safeColumns = math.max(columns, 0);
  if (safeSegments == 0 || size.height <= 0 || srcRect.isEmpty) {
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List(0),
      textureCoordinates: Float32List(0),
    );
  }

  final height = size.height;
  final totalCols = safeColumns + 2; // fold + interior + flap edge columns
  final rows = safeSegments + 1;
  final vertexCount = rows * totalCols;
  if (vertexCount > 0x10000) {
    throw ArgumentError.value(
      vertexCount,
      'segments/columns',
      'Flap mesh exceeds Uint16 index capacity',
    );
  }

  // -----------------------------------------------------------------------
  // 1. Build vertex grid [rows] × [totalCols] in a flat array.
  //
  // Store each grid point once, then reference it from Uint16 indices below.
  // At the default density this keeps 102 positions/UVs instead of expanding
  // the same coordinates into 160 duplicated triangle vertices per mesh.
  //
  //   fold  col1  col2  col3  col4  flap
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row 0 (top)
  //    │╲    │     │     │     │    ╱│
  //    │ ╲   │     │ ╶───→│     │   ╱ │   bulge peak (more left shift)
  //    │  ╲  │     │     │     │  ╱  │
  //    ┼─────┼─────┼─────┼─────┼─────┼   ← row N (bottom)
  // -----------------------------------------------------------------------
  final positions = Float32List(vertexCount * 2);
  final texCoords = Float32List(vertexCount * 2);

  // Surface bulge factor: how much extra curvature interior columns get.
  // 30% additional bezier offset at the midpoint column creates visible
  // 3D curvature without looking like tightly rolled paper.
  const kBulgeStrength = 0.30;
  final colScale = 1.0 / (totalCols - 1);

  for (var i = 0; i < rows; i++) {
    final t = i / safeSegments;
    final y = height * t;
    // Use the same extended vertical domain as the screen clip. UVs still use
    // the visible 0..1 [t] below; only the projected paper position is curved.
    final b = flapCurveBlendAt(y, height);
    final rowBase = i * totalCols;

    for (var j = 0; j < totalCols; j++) {
      final s = j * colScale; // 0 at fold, 1 at flap edge

      // Interior columns get amplified bezier offset → surface bulge.
      // sin(s*pi) peaks at s=0.5 and is zero at both edges, so the bulge
      // smoothly blends to the existing fold/flap edge positions.
      final bulgeScale = safeColumns > 0 ? math.sin(s * math.pi) : 0.0;
      final colCurveScale = 1.0 + kBulgeStrength * bulgeScale;
      final colOffset = curveOffset * colCurveScale;

      // Column bezier-fold position at this row.
      final foldAtY = foldX - colOffset * b;
      final flapAtY = flapLeft - colOffset * b;

      final idx = rowBase + j;
      final coord = idx * 2;
      // Interpolate X between fold and flap edge for this column.
      positions[coord] = foldAtY + (flapAtY - foldAtY) * s;
      positions[coord + 1] = y;
      // UV: right→left from srcRect.right (fold) to srcRect.left (flap edge).
      // flipHorizontal for mirrored 2.5D back content on double-spread.
      texCoords[coord] = flipHorizontal
          ? srcRect.left + s * srcRect.width
          : srcRect.right - s * srcRect.width;
      texCoords[coord + 1] = srcRect.top + t * srcRect.height;
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
  // Indexed vertices keep each grid point once and reference it from triangle
  // pairs. This preserves the exact mesh topology while avoiding duplicated
  // position/UV payload for every triangle.
  // -----------------------------------------------------------------------
  final indexCount = safeSegments * (totalCols - 1) * 6;
  final indices = Uint16List(indexCount);
  var offset = 0;

  for (var i = 0; i < safeSegments; i++) {
    final row0 = i * totalCols;
    final row1 = (i + 1) * totalCols;
    for (var j = 0; j < totalCols - 1; j++) {
      final i0j0 = row0 + j;
      final i0j1 = row0 + j + 1;
      final i1j0 = row1 + j;
      final i1j1 = row1 + j + 1;

      // Triangle 1: (i,j), (i+1,j), (i,j+1)
      indices[offset++] = i0j0;
      indices[offset++] = i1j0;
      indices[offset++] = i0j1;

      // Triangle 2: (i,j+1), (i+1,j), (i+1,j+1)
      indices[offset++] = i0j1;
      indices[offset++] = i1j0;
      indices[offset++] = i1j1;
    }
  }

  return ui.Vertices.raw(
    ui.VertexMode.triangles,
    positions,
    textureCoordinates: texCoords,
    indices: indices,
  );
}

/// Clip rect for flap-side drop shadows in [PageFlipPainter].
///
/// Double-spread: the active turning half. Single-page: the side of the fold
/// occupied by the turning flap.
@visibleForTesting
Rect flipSideShadowClipRect(PageFlipGeometry geo) {
  if (geo.isDoubleSpread) {
    return geo.isForward
        ? Rect.fromLTWH(
            geo.spineX,
            0,
            geo.size.width - geo.spineX,
            geo.size.height,
          )
        : Rect.fromLTWH(0, 0, geo.spineX, geo.size.height);
  }
  final fold = geo.foldX.clamp(0.0, geo.size.width);
  if (geo.flapRightOfFold) {
    return Rect.fromLTWH(0, 0, fold, geo.size.height);
  }
  return Rect.fromLTWH(fold, 0, geo.size.width - fold, geo.size.height);
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
  double endRevealStrength = 0.0,
  double endRevealStart = 0.85,
  bool isForward = true,
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

  return (1.0 - thinFactor - endFactor).clamp(0.05, 1.0);
}
