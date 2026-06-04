import 'dart:math' as math;
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

/// Source/destination pair for flap-front texture after foreshortening alignment.
class FlapFrontTextureMapping {
  /// Creates a [FlapFrontTextureMapping].
  const FlapFrontTextureMapping({
    required this.srcRect,
    required this.destRect,
  });

  /// Sub-rect within the spread snapshot for the visible flap strip.
  final Rect srcRect;

  /// Canvas rect matching the clipped flap strip (pre-transform local space).
  final Rect destRect;
}

/// Maps flap snapshot UVs onto the visible flap strip.
///
/// [PageFlipGeometry.flapVisibleWidth] is narrower than the physical material
/// width for foreshortening. Mapping the full page half onto the canvas and
/// clipping to the flap strip zooms text ("magnifying lens"). This helper
/// scales source and destination to the visible strip only.
FlapFrontTextureMapping? flapFrontAlignedTextureMapping({
  required Rect baseSrcRect,
  required Rect baseDestRect,
  required PageFlipGeometry geo,
}) {
  if (baseSrcRect.isEmpty || baseDestRect.isEmpty) return null;

  final flapMaterialWidth = geo.size.width - geo.foldX;
  if (flapMaterialWidth <= 0.001 || geo.flapVisibleWidth <= 0.001) {
    return null;
  }

  final hiddenMaterial = flapMaterialWidth - geo.flapVisibleWidth;
  final srcWidthRatio = geo.flapVisibleWidth / flapMaterialWidth;
  final srcOffsetRatio = hiddenMaterial / flapMaterialWidth;

  final srcRect = Rect.fromLTWH(
    baseSrcRect.left + baseSrcRect.width * srcOffsetRatio,
    baseSrcRect.top,
    baseSrcRect.width * srcWidthRatio,
    baseSrcRect.height,
  );

  final destRect = Rect.fromLTWH(
    geo.flapLeft,
    0,
    geo.flapVisibleWidth,
    geo.size.height,
  );

  if (!destRect.overlaps(baseDestRect.inflate(0.5))) return null;

  return FlapFrontTextureMapping(srcRect: srcRect, destRect: destRect);
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
}) {
  // Phase 1: brief early visibility → fast hide as fold begins.
  if (progress <= fadeOutEnd) {
    if (fadeOutEnd <= 0) return 0.0;
    final t = 1.0 - progress / fadeOutEnd;
    return t * t * (3 - 2 * t);
  }

  // Phase 2: mid fold — paper back only (longest phase).
  if (progress < revealStart) return 0.0;

  // Phase 3: late settle reveal.
  if (progress >= revealEnd) return 1.0;
  final t = (progress - revealStart) / (revealEnd - revealStart);
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

    // Use current logic but ensure it supports smooth reversing
    // Forward (progress 0..1): Page moves Right -> Left. foldX moves Width -> spineX.
    // Backward (progress 1..0): Page moves Left -> Right. foldX moves spineX -> Width.
    // foldX is the hinge point where the paper is folded.
    final pageWidth = isDoubleSpread ? width / 2 : width;
    foldX = width - (pageWidth * progress);

    // Asymmetric rotation angle profile: fast rise (~40% of flip), slower
    // settle (~60%). Real paper accelerates quickly when pushed, then
    // decelerates mid-turn due to air resistance and paper stiffness.
    final angleT = math.pow(progress, 0.82).toDouble();
    final angleProfile = math.sin(angleT * math.pi);
    final baseAngle = (touchOffset.dy / height - 0.5) *
        _kAngleScale *
        angleProfile;

    // Ensure fold line doesn't detach from the spine (spineX) within the screen bounds
    final limitLeft = math.atan2(foldX - spineX, height / 2);
    final limitRight = math.atan2(width - foldX, height / 2);
    final absLimit = math.max(0.0, math.min(limitLeft, limitRight));

    angle = baseAngle.clamp(-absLimit, absLimit);

    // Create the transformation matrix (Hinge stays on the foldX)
    transform = Matrix4.identity()
      ..multiply(Matrix4.translationValues(foldX, height / 2, 0))
      ..rotateZ(-angle) // Negated angle for standard R-to-L feel
      ..multiply(Matrix4.translationValues(-foldX, -height / 2, 0));

    // Calculate fold line endpoints (extended for clean clipping)
    foldLineTop = MatrixUtils.transformPoint(transform, Offset(foldX, -height));
    foldLineBottom = MatrixUtils.transformPoint(
      transform,
      Offset(foldX, height * 2),
    );

    // Shadow intensity (peaks at middle of animation)
    shadowIntensity = math.sin(progress * math.pi);

    // Flap dimensions with foreshortening effect
    // In our model, the "flap" is the part of the paper being peeled from the right edge.
    final flapMaterialWidth = width - foldX;

    // Preserving total width, but adding a curve effect using sine easing
    flapVisibleWidth = flapMaterialWidth *
        (_kFlapWidthBase - _kFlapWidthModulation * math.sin(progress * math.pi));

    // Flap attaches to foldX and extends Left.
    flapLeft = foldX - flapVisibleWidth;

    // Calculate flap edge endpoints (Left edge of the flap)
    flapEdgeTop = MatrixUtils.transformPoint(
      transform,
      Offset(flapLeft, -height),
    );
    flapEdgeBottom = MatrixUtils.transformPoint(
      transform,
      Offset(flapLeft, height * 2),
    );

    // -----------------------------------------------------------------------
    // Fold curvature — bezier control offsets create a natural paper curl.
    // Peak curvature occurs mid-flip (progress ≈ 0.5), flat at both ends.
    // The control-point offset is ~4% of page width for subtle but visible
    // curl. Direction matches the flip direction so the middle of the page
    // lags behind — correct inertia/air-resistance for real paper.
    // -----------------------------------------------------------------------
    curvatureAmount = math.sin(progress * math.pi);
    final curveDirection = isForward ? 1.0 : -1.0;
    curveOffset = curvatureAmount * pageWidth * 0.04 * curveDirection;
    // For a natural peel from the right to left, the middle of the fold line
    // lags slightly behind the top/bottom corners, creating a leftward bulge.
    // In untransformed space, we move the control point left (-X).
    foldCurveControl = MatrixUtils.transformPoint(
      transform,
      Offset(foldX - curveOffset, height / 2),
    );

    // The flap's left edge should also curve in the same direction
    // to maintain constant paper width and avoid hourglass stretching.
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

/// CustomPainter that renders the flipping page flap with shadow and highlight effects.
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
    final isPaperLight = luminance > 0.5;
    final isPaperDark = luminance < 0.20; // catches dark mode backgrounds

    canvas.save();
    canvas.transform(g.transform.storage);

    // Clip to flap region using the curved path in local space
    final flapRect = Rect.fromLTWH(
      g.flapLeft,
      0,
      g.flapVisibleWidth,
      size.height,
    );

    canvas.clipPath(buildFlapClipPathLocal(g));

    // Layer 1: Paper back underlay, then flap-front texture with late reveal.
    final paperPaint = Paint()
      ..color = paperBackColor.withValues(
        alpha: paperOpacity == 1.0
            ? 1.0
            : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0),
      );
    canvas.drawRect(flapRect, paperPaint);

    final hasFlapTexture =
        flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final contentReveal = flapFrontContentRevealOpacity(
        progress,
        fadeOutEnd: flapContentFadeOutEnd,
        revealStart: flapContentRevealStart,
        revealEnd: flapContentRevealEnd,
      );
      if (contentReveal > 0.001) {
        final pageRect = flapFrontDestRect ??
            (isDoubleSpread
                ? Rect.fromLTWH(
                    g.spineX, 0, size.width - g.spineX, size.height,
                  )
                : Rect.fromLTWH(0, 0, size.width, size.height));
        final mapping = flapFrontAlignedTextureMapping(
          baseSrcRect: flapFrontSrcRect!,
          baseDestRect: pageRect,
          geo: g,
        );
        final srcRect = mapping?.srcRect ?? flapFrontSrcRect!;
        final destRect = mapping?.destRect ?? pageRect;
        canvas.drawImageRect(
          flapFrontImage!,
          srcRect,
          destRect,
          Paint()
            ..filterQuality = FilterQuality.medium
            ..color = Color.fromRGBO(255, 255, 255, contentReveal),
        );
      }
    }

    // Layer 2: Soft Highlight
    // Option B: Dramatically increase the highlight and spread it wider.
    // By creating a strong, glossy light reflection on the crease, the eye is drawn to the 3D geometry rather than the blank paper.
    final highlightAlpha = isPaperLight ? 0.22 : (isPaperDark ? 0.28 : 0.22);
    if (highlightAlpha > 0.01) {
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: isRightToLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: isRightToLeft ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Colors.white.withValues(alpha: highlightAlpha),
              Colors.white.withValues(alpha: highlightAlpha * 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.8],
          ).createShader(flapRect),
      );
    }

    // Layer 3: Inner Shadow
    // Deepen the inner shadow near the fold to enhance the dramatic 3D curvature.
    final shadowBase = (isPaperDark ? 0.30 : 0.45) * g.shadowIntensity;
    final shadowMid  = (isPaperDark ? 0.12 : 0.18) * g.shadowIntensity;
    if (shadowBase > 0.01) {
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            begin: isRightToLeft ? Alignment.centerRight : Alignment.centerLeft,
            end: isRightToLeft ? Alignment.centerLeft : Alignment.centerRight,
            colors: [
              Colors.black.withValues(alpha: shadowBase),
              Colors.black.withValues(alpha: shadowMid),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 1.0],
          ).createShader(flapRect),
      );
    }

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
      oldDelegate.paperBackColor != paperBackColor ||
      oldDelegate.isDoubleSpread != isDoubleSpread ||
      oldDelegate.isForward != isForward ||
      oldDelegate.paperOpacity != paperOpacity ||
      oldDelegate.flapContentFadeOutEnd != flapContentFadeOutEnd ||
      oldDelegate.flapContentRevealStart != flapContentRevealStart ||
      oldDelegate.flapContentRevealEnd != flapContentRevealEnd ||
      oldDelegate.flapFrontImage != flapFrontImage ||
      oldDelegate.flapFrontSrcRect != flapFrontSrcRect ||
      oldDelegate.flapFrontDestRect != flapFrontDestRect;
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
