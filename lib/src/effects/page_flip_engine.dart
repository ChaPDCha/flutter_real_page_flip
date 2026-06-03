import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Flap front texture helpers
// ---------------------------------------------------------------------------

/// Returns the source rect within a spread snapshot for the flipping flap front.
///
/// Forward double-spread flips use the left half of the next spread snapshot;
/// backward use the right half of the previous spread. Single-page backward
/// flips use paper back only.
Rect? flapFrontSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
}) {
  if (isDoubleSpread) {
    final halfWidth = imageSize.width / 2;
    if (isForward) {
      // Forward flip: Flap represents next left page (Page 4) -> Left half of next spread snapshot
      return Rect.fromLTWH(0, 0, halfWidth, imageSize.height);
    }
    // Backward flip: Flap represents previous right page (Page 3) -> Right half of previous spread snapshot
    return Rect.fromLTWH(halfWidth, 0, halfWidth, imageSize.height);
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
      // Forward flip: Next left page lands on the left half of the screen
      return Rect.fromLTWH(0, 0, halfWidth, size.height);
    }
    // Backward flip: Previous right page lands on the right half of the screen
    return Rect.fromLTWH(halfWidth, 0, halfWidth, size.height);
  }

  return Rect.fromLTWH(0, 0, size.width, size.height);
}

/// Sub-pixel overlap (px) between spine-reveal clip and flap layer 3.
///
/// Prevents hairline gaps between [PageFlipSpineRevealClipper] and
/// [PageFlipPainter] without changing visible fold geometry when
/// [PageFlipGeometry.curvatureAmount] is 0.
const double kSpineRevealOverlapPx = 1.5;

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

/// Clips [child] to the left or right half of a double-spread page widget.
///
/// Use the same helper for stationary spread halves, spine-band reveal, and
/// host `itemBuilder` layouts so half-page alignment stays consistent.
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

    // Rotation angle based on touch Y with pinned boundary compliance
    final baseAngle = (touchOffset.dy / height - 0.5) *
        _kAngleScale *
        math.sin(progress * math.pi);

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
    // Curvature Disabled (As requested: Reverted to solid, flat 2D opaque folds)
    // -----------------------------------------------------------------------
    curvatureAmount = 0.0;
    curveOffset = 0.0;

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

/// Builds the clip path that progressively reveals the adjacent spread page
/// in the spine band during a double-spread flip.
///
/// Forward: next spread's left page between spine and the flap's left edge.
/// Backward: previous spread's right page between spine and the fold (flap) line.
///
/// Returns `null` when reveal should not be drawn (no crossing yet or invalid).
Path? buildDoubleSpreadSpineRevealPath(PageFlipGeometry geo) {
  if (!geo.isDoubleSpread || geo.progress <= 0 || geo.spineX <= 0) {
    return null;
  }
  final edges = spineRevealClipEdges(geo);
  if (edges == null) return null;
  return _pathFromSpineRevealEdges(geo, edges);
}

/// Shared spine-band edge coordinates for forward/backward reveal clips.
///
/// Returns `null` until the flap has crossed the spine (same gate as
/// [buildDoubleSpreadSpineRevealPath]). When [PageFlipGeometry.curvatureAmount]
/// is re-enabled, both reveal and flap paths should use these edges.
SpineRevealClipEdges? spineRevealClipEdges(PageFlipGeometry geo) {
  if (!geo.isDoubleSpread) return null;

  if (geo.isForward) {
    if (geo.flapLeft >= geo.spineX) return null;
    final overlapShift = -kSpineRevealOverlapPx;
    return SpineRevealClipEdges(
      overlapShift: overlapShift,
      edgeBottom: Offset(geo.flapEdgeBottom.dx + overlapShift, geo.flapEdgeBottom.dy),
      edgeTop: Offset(geo.flapEdgeTop.dx + overlapShift, geo.flapEdgeTop.dy),
      curveControl: Offset(geo.flapCurveControl.dx + overlapShift, geo.flapCurveControl.dy),
    );
  }

  if (geo.flapLeft <= geo.spineX) return null;
  final overlapShift = kSpineRevealOverlapPx;
  return SpineRevealClipEdges(
    overlapShift: overlapShift,
    edgeBottom: Offset(geo.foldLineBottom.dx + overlapShift, geo.foldLineBottom.dy),
    edgeTop: Offset(geo.foldLineTop.dx + overlapShift, geo.foldLineTop.dy),
    curveControl: Offset(geo.foldCurveControl.dx + overlapShift, geo.foldCurveControl.dy),
  );
}

/// Trailing edge of the spine reveal band (flap or fold line + overlap).
class SpineRevealClipEdges {
  /// Creates [SpineRevealClipEdges].
  const SpineRevealClipEdges({
    required this.overlapShift,
    required this.edgeBottom,
    required this.edgeTop,
    required this.curveControl,
  });

  /// Signed overlap applied to trailing edge X (and curve control when curved).
  final double overlapShift;

  /// Bottom point of the reveal band's trailing edge.
  final Offset edgeBottom;

  /// Top point of the reveal band's trailing edge.
  final Offset edgeTop;

  /// Quadratic bezier control when [PageFlipGeometry.curvatureAmount] > 0.
  final Offset curveControl;
}

Path _pathFromSpineRevealEdges(PageFlipGeometry geo, SpineRevealClipEdges edges) {
  final path = Path()
    ..moveTo(geo.spineX, 0)
    ..lineTo(geo.spineX, geo.size.height)
    ..lineTo(edges.edgeBottom.dx, edges.edgeBottom.dy);

  if (geo.curvatureAmount > 0.001) {
    path.quadraticBezierTo(
      edges.curveControl.dx,
      edges.curveControl.dy,
      edges.edgeTop.dx,
      edges.edgeTop.dy,
    );
  } else {
    path.lineTo(edges.edgeTop.dx, edges.edgeTop.dy);
  }
  path.close();
  return path;
}

/// Clips to the spine–trailing-edge reveal band for double-spread forward flips.
class PageFlipSpineRevealClipper extends CustomClipper<Path> {
  /// Creates a [PageFlipSpineRevealClipper].
  PageFlipSpineRevealClipper({required this.geo});

  /// Shared flip geometry for this frame.
  final PageFlipGeometry geo;

  @override
  Path getClip(Size size) =>
      buildDoubleSpreadSpineRevealPath(geo) ?? Path();

  @override
  bool shouldReclip(PageFlipSpineRevealClipper oldClipper) =>
      oldClipper.geo.progress != geo.progress ||
      oldClipper.geo.touchOffset != geo.touchOffset ||
      oldClipper.geo.isDoubleSpread != geo.isDoubleSpread ||
      oldClipper.geo.isForward != geo.isForward;
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

    /// Pre-captured snapshot of the flipping page front (flap texture).
    this.flapFrontImage,

    /// Source rect within [flapFrontImage] to map onto the flap.
    this.flapFrontSrcRect,

    /// Destination rect for [flapFrontSrcRect] on the canvas (defaults to right page).
    this.flapFrontDestRect,
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

  /// Pre-captured snapshot of the flipping page front (flap texture).
  final ui.Image? flapFrontImage;

  /// Source rect within [flapFrontImage] to map onto the flap.
  final Rect? flapFrontSrcRect;

  /// Destination rect for flap front texture (null = legacy right-page mapping).
  final Rect? flapFrontDestRect;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) {
      return;
    }

    // Use shared geometry calculations
    final geo = PageFlipGeometry(
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
    canvas.transform(geo.transform.storage);

    // Clip to flap region using the curved path in local space
    final flapRect = Rect.fromLTWH(
      geo.flapLeft,
      0,
      geo.flapVisibleWidth,
      size.height,
    );
    
    final flapPath = Path();
    flapPath.moveTo(geo.flapLeft, 0);
    flapPath.lineTo(geo.foldX, 0);
    
    if (geo.curvatureAmount > 0.001) {
      // Right edge (fold line) in local space
      flapPath.quadraticBezierTo(
        geo.foldX - geo.curveOffset, size.height / 2, 
        geo.foldX, size.height,
      );
      flapPath.lineTo(geo.flapLeft, size.height);
      // Left edge (flap edge) in local space (curving in the same direction)
      flapPath.quadraticBezierTo(
        geo.flapLeft - geo.curveOffset, size.height / 2,
        geo.flapLeft, 0,
      );
    } else {
      flapPath.lineTo(geo.foldX, size.height);
      flapPath.lineTo(geo.flapLeft, size.height);
    }
    flapPath.close();

    canvas.clipPath(flapPath);

    // Layer 1: Flap front texture (snapshot-mapped) or paper back fallback
    // 항상 스냅샷이 있으면 플랩에 텍스처를 입힌다.
    // 단면 모드에서도 현재 페이지 내용이 플랩에 보여야
    // "빈 종이" 느낌이 사라진다.
    final hasFlapTexture =
        flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final pageRect = flapFrontDestRect ??
          (isDoubleSpread
              ? Rect.fromLTWH(
                  geo.spineX, 0, size.width - geo.spineX, size.height,
                )
              : Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawImageRect(
        flapFrontImage!,
        flapFrontSrcRect!,
        pageRect,
        Paint()..filterQuality = FilterQuality.medium,
      );
    } else {
      canvas.drawRect(
        flapRect,
        Paint()
          ..color = paperBackColor.withValues(
            alpha: paperOpacity == 1.0
                ? 1.0
                : (isPaperDark ? paperOpacity * 1.1 : paperOpacity)
                    .clamp(0.0, 1.0),
          ),
      );
    }

    // Layer 2: Soft Highlight
    // Option B: Dramatically increase the highlight and spread it wider.
    // By creating a strong, glossy light reflection on the crease, the eye is drawn to the 3D geometry rather than the blank paper.
    final highlightAlpha = isPaperLight ? 0.35 : (isPaperDark ? 0.45 : 0.35);
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
    final shadowBase = (isPaperDark ? 0.30 : 0.45) * geo.shadowIntensity;
    final shadowMid  = (isPaperDark ? 0.12 : 0.18) * geo.shadowIntensity;
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
    canvas.clipRect(flipSideShadowClipRect(geo));
    canvas.transform(geo.transform.storage);

    final shadowWidth = _kRevealedShadowWidth * geo.shadowIntensity;
    final revealedAlpha = 0.15 * geo.shadowIntensity;
    if (revealedAlpha > 0.01 && shadowWidth > 1) {
      final revealedRect = Rect.fromLTWH(
        geo.foldX,
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
      canvas.clipRect(flipSideShadowClipRect(geo));
      canvas.transform(geo.transform.storage);

      final stationaryWidth = _kStationaryShadowWidth * geo.shadowIntensity;
      final stationaryAlpha = 0.05 * geo.shadowIntensity;
      if (stationaryAlpha > 0.01 && stationaryWidth > 1) {
        final stationaryRect = Rect.fromLTWH(
          geo.foldX - geo.flapVisibleWidth - stationaryWidth,
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

    // Draw Center Spine Shadow for Double Spread
    if (isDoubleSpread && progress > 0) {
      const spineShadowWidth = 30.0;
      final spineRect = Rect.fromLTWH(geo.spineX, 0, spineShadowWidth, size.height);
      canvas.drawRect(
        spineRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.15 * geo.shadowIntensity),
              Colors.transparent,
            ],
          ).createShader(spineRect),
      );
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

  @override
  Path getClip(Size size) {
    if (progress <= 0) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    // FIX: If progress is >= 1, the page should be fully flipped (invisible/gone).
    if (progress >= 1) {
      return Path(); // Empty path
    }

    // Use shared geometry calculations
    final geo = PageFlipGeometry(
      progress: progress,
      isRightToLeft: isRightToLeft,
      touchOffset: touchOffset,
      size: size,
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
    );

    final path = Path();
    // Shift the fold line slightly to the right to create a small overlap.
    // Since PageFlipClipper is Layer 2 (drawn on top of Layer 1), this covers any subpixel gaps.
    const overlapShift = 1.5;
    path.moveTo(0, 0);
    path.lineTo(geo.foldLineTop.dx + overlapShift, geo.foldLineTop.dy);
    
    if (geo.curvatureAmount > 0.001) {
      path.quadraticBezierTo(
        geo.foldCurveControl.dx + overlapShift,
        geo.foldCurveControl.dy,
        geo.foldLineBottom.dx + overlapShift,
        geo.foldLineBottom.dy,
      );
    } else {
      path.lineTo(geo.foldLineBottom.dx + overlapShift, geo.foldLineBottom.dy);
    }
    
    path.lineTo(0, size.height);
    path.close();

    return path;
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

  @override
  Path getClip(Size size) {
    if (progress <= 0 || progress >= 1) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    // Use shared geometry
    final geo = PageFlipGeometry(
      progress: progress,
      isRightToLeft: isRightToLeft,
      touchOffset: touchOffset,
      size: size,
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
    );

    final path = Path();

    // Keep RIGHT portion (Fold to Width).
    path.moveTo(size.width, 0);
    path.lineTo(geo.foldLineTop.dx, geo.foldLineTop.dy);
    
    if (geo.curvatureAmount > 0.001) {
      path.quadraticBezierTo(
        geo.foldCurveControl.dx,
        geo.foldCurveControl.dy,
        geo.foldLineBottom.dx,
        geo.foldLineBottom.dy,
      );
    } else {
      path.lineTo(geo.foldLineBottom.dx, geo.foldLineBottom.dy);
    }
    
    path.lineTo(size.width, size.height);
    path.close();

    return path;
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

  /// True when accumulated movement should start a page-flip drag.
  static bool shouldAcceptFlipDrag({
    required double totalDx,
    required double totalDy,
    required double sensitivity,
  }) {
    final checkSlop = checkSlopForSensitivity(sensitivity);

    if (totalDy.abs() > checkSlop && totalDy.abs() > totalDx.abs() * 1.2) {
      return false;
    }

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

  @override
  /// Resets accumulated deltas when a new pointer is added.
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _totalDx = 0.0;
    _totalDy = 0.0;
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _totalDx += event.delta.dx;
      _totalDy += event.delta.dy;
    }
    super.handleEvent(event);
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
