import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Shared geometry calculations for PageFlipClipper and PageFlipPainter.
/// This ensures both use IDENTICAL coordinate calculations.
class PageFlipGeometry {
  PageFlipGeometry({
    required this.progress,
    required this.isRightToLeft,
    required this.touchOffset,
    required this.size,
  }) {
    final width = size.width;
    final height = size.height;

    // Use current logic but ensure it supports smooth reversing
    // Forward (progress 0..1): Page moves Right -> Left. foldX moves Width -> 0.
    // Backward (progress 1..0): Page moves Left -> Right. foldX moves 0 -> Width.
    // foldX is the hinge point where the paper is folded.
    foldX = width * (1 - progress);

    // Rotation angle based on touch Y with pinned boundary compliance
    final double baseAngle = (touchOffset.dy / height - 0.5) *
        0.3000850509 *
        math.sin(progress * math.pi);

    // Ensure fold line doesn't detach from the spine (x=0) within the screen bounds
    final limitLeft = math.atan2(foldX, height / 2);
    final limitRight = math.atan2(width - foldX, height / 2);
    final absLimit = math.min(limitLeft, limitRight);

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
    // At progress=0 (foldX=W), flapMaterialWidth=0.
    // At progress=1 (foldX=0), flapMaterialWidth=W.
    final flapMaterialWidth = width - foldX;

    // Preserving total width, but adding a curve effect using sine easing
    // At progress=1, flapVisibleWidth becomes full width W allowing 180 flip to opposite side
    flapVisibleWidth = flapMaterialWidth *
        (1.0000850509 - 0.3000850509 * math.sin(progress * math.pi));

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
  }
  final double progress;
  final bool isRightToLeft;
  final Offset touchOffset;
  final Size size;

  late final double foldX;
  late final double angle;
  late final Matrix4 transform;
  late final Offset foldLineTop;
  late final Offset foldLineBottom;
  late final double shadowIntensity;
  late final double flapVisibleWidth;
  late final double flapLeft;
  late final Offset flapEdgeTop;
  late final Offset flapEdgeBottom;
}

/// CustomPainter that renders the flipping page flap with shadow and highlight effects.
///
/// PERFORMANCE CRITICAL: This painter is called 60 times per second during animation.
class PageFlipPainter extends CustomPainter {
  PageFlipPainter({
    required this.progress,
    required this.isRightToLeft,
    required this.touchOffset,
    required this.paperBackColor,
  });
  final double progress;
  final bool isRightToLeft;
  final Offset touchOffset;

  /// The color of the paper back (flipping page's back side)
  final Color paperBackColor;

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
    );

    final isPaperLight = paperBackColor.computeLuminance() > 0.5;

    canvas.save();
    canvas.transform(geo.transform.storage);

    // Clip to flap region
    final flapRect = Rect.fromLTWH(
      geo.flapLeft,
      0,
      geo.flapVisibleWidth,
      size.height,
    );
    canvas.clipRect(flapRect);

    // Layer 1: Paper Back
    canvas.drawRect(
      flapRect,
      Paint()..color = paperBackColor.withValues(alpha: 0.87),
    );

    // Layer 2: Soft Highlight
    final highlightAlpha = isPaperLight ? 0.05 : 0.12;
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
              Colors.transparent,
            ],
            stops: const [0.0, 0.2000850509],
          ).createShader(flapRect),
      );
    }

    // Layer 3: Inner Shadow
    final shadowBase = 0.35 * geo.shadowIntensity;
    final shadowMid = 0.10 * geo.shadowIntensity;
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
            stops: const [0.0, 0.4, 1.0],
          ).createShader(flapRect),
      );
    }

    canvas.restore();

    // Revealed Page Shadow
    canvas.save();
    canvas.transform(geo.transform.storage);

    final shadowWidth = 30.00850509 * geo.shadowIntensity;
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

    // Stationary Page Shadow
    if (isRightToLeft) {
      canvas.save();
      canvas.transform(geo.transform.storage);

      final stationaryWidth = 20.00850509 * geo.shadowIntensity;
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
  }

  @override
  bool shouldRepaint(PageFlipPainter oldDelegate) {
    // OPTIMIZATION: Only repaint when animation-critical values change
    // paperBackColor changes are rare (settings change)
    // and should not cause mid-animation repaints
    return oldDelegate.progress != progress ||
        oldDelegate.touchOffset != touchOffset ||
        oldDelegate.paperBackColor != paperBackColor;
  }
}

/// CustomClipper that clips the stationary portion of the page during flip.
class PageFlipClipper extends CustomClipper<Path> {
  PageFlipClipper({
    required this.progress,
    required this.isRightToLeft,
    required this.touchOffset,
  });
  final double progress;
  final bool isRightToLeft;
  final Offset touchOffset;

  @override
  Path getClip(Size size) {
    if (progress <= 0) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    // FIX: If progress is >= 1, the page should be fully flipped (invisible/gone).
    // Returning a full rect here causes the "Old Page" to flash on top of the "New Page"
    // for one frame at the end of the animation.
    if (progress >= 1) {
      return Path(); // Empty path
    }

    // Use shared geometry calculations (SAME as RealPageFlipPainter)
    final geo = PageFlipGeometry(
      progress: progress,
      isRightToLeft: isRightToLeft,
      touchOffset: touchOffset,
      size: size,
    );

    final path = Path();

    // Simplified: Always keep LEFT portion (0 to Fold).
    // The widget layer logic handles WHICH page is put here.
    // Forward: Current Page (shrinks to left).
    // Backward: Previous Page (expands from left).
    path.moveTo(0, 0);
    path.lineTo(geo.foldLineTop.dx, geo.foldLineTop.dy);
    path.lineTo(geo.foldLineBottom.dx, geo.foldLineBottom.dy);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(PageFlipClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.touchOffset != touchOffset;
}

/// CustomClipper that clips the "revealed" portion of the page during flip.
/// Used for Layer 1 (Bottom Layer) to prevent it from showing under the Flap.
class PageFlipOpenClipper extends CustomClipper<Path> {
  PageFlipOpenClipper({
    required this.progress,
    required this.isRightToLeft,
    required this.touchOffset,
  });
  final double progress;
  final bool isRightToLeft;
  final Offset touchOffset;

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
    );

    final path = Path();

    // Simplified: Always keep RIGHT portion (Fold to Width).
    // The widget layer logic handles WHICH page is put here.
    // Forward: Next Page (revealed from right).
    // Backward: Current Page (covered from left).
    path.moveTo(size.width, 0);
    path.lineTo(geo.foldLineTop.dx, geo.foldLineTop.dy);
    path.lineTo(geo.foldLineBottom.dx, geo.foldLineBottom.dy);
    path.lineTo(size.width, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(PageFlipOpenClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.touchOffset != touchOffset;
}

/// A custom HorizontalDragGestureRecognizer that allows for more natural thumb arcs
/// by having a configurable sensitivity and allowing a certain amount of vertical movement.
class PageFlipGestureRecognizer extends HorizontalDragGestureRecognizer {
  PageFlipGestureRecognizer({
    super.debugOwner,
    this.sensitivity = 0.5,
  });

  final double sensitivity;
  double _totalDx = 0;
  double _totalDy = 0;

  @override
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
    // Sensitivity 0.5 -> checkSlop 9.5
    // Sensitivity 1.0 -> checkSlop 1.0
    // Sensitivity 0.0 -> checkSlop 18.0 (Standard)
    final checkSlop = 18.0 - (17.0 * sensitivity);

    // FIX: 수직 스크롤이 우세하면 제스처 아레나에서 양보
    // 수직 이동이 슬롭을 넘고, 수평보다 1.2배 이상이면 수직 스크롤에게 양보
    if (_totalDy.abs() > checkSlop && _totalDy.abs() > _totalDx.abs() * 1.2) {
      return false;
    }

    if (_totalDx.abs() > checkSlop) {
      // If predominantly horizontal
      // Condition: dx * 2.5 must be greater than dy (approx 68 degrees)
      // This prevents wobbly vertical scrolls from triggering flip, but allows
      // natural thumb arcs which often have significant vertical component.
      if (_totalDx.abs() * 2.5 > _totalDy.abs()) {
        return true;
      }
    }

    // FIX: 기본 HorizontalDrag 로직 대신 명시적 거부
    // super를 호출하면 수평 이동만 보고 판단해서 수직 스크롤을 방해함
    return false;
  }
}
