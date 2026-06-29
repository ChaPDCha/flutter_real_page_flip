part of 'page_flip_engine.dart';

// ---------------------------------------------------------------------------
// Geometry & rendering constants
// ---------------------------------------------------------------------------

/// Scales the vertical touch offset to the fold rotation angle.
/// ~0.30 rad ≈ 17° max tilt — tuned empirically for natural paper-feel.
const double _kAngleScale = 0.30;

/// Base multiplier for visible flap width during foreshortening.
const double _kFlapWidthBase = 1;

/// Sine modulation amplitude for flap-width foreshortening.
/// At mid-flip the visible flap width narrows by this fraction to simulate
/// perspective foreshortening of the curling paper edge.
const double _kFlapWidthModulation = 0.30;

/// Maximum width (px) of the drop shadow cast by the revealed (new) page.
const double _kRevealedShadowWidth = 30;

/// Maximum width (px) of the shadow on the stationary page edge.
const double _kStationaryShadowWidth = 20;

/// Pre-computed identity matrix storage for [ui.ImageShader] transforms.
/// Avoids allocating a new [Matrix4] + extracting storage every paint frame.
final Float64List _identityMatrixStorage = Matrix4.identity().storage;

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
  const PaperFlipCurve() : super(0.05, 0.7, 0.1, 1);
}

/// Smooth tap-flip curve gentler than [PaperFlipCurve] for short programmatic
/// flips where the user is not providing momentum via drag.
class TapFlipCurve extends Curve {
  /// Creates a tap flip curve.
  const TapFlipCurve();

  @override
  double transformInternal(double t) =>
      // Softer bell: ease-in-out-quart profile.
      // Slower start (no user momentum), smooth mid, gentle settle.
      t < 0.5
          ? 4.0 * t * t * t
          : 1.0 - math.pow(-2.0 * t + 2.0, 3).toDouble() / 2.0;
}

/// Shared geometry calculations for PageFlipClipper and PageFlipPainter.
/// This ensures both use IDENTICAL coordinate calculations.
class PageFlipGeometry {
  /// Creates a [PageFlipGeometry] instance that computes all derived
  /// fold, flap, and shadow values from the input parameters.
  factory PageFlipGeometry({
    required double progress,
    required bool isRightToLeft,
    required Offset touchOffset,
    required Size size,
    bool isDoubleSpread = false,
    bool isForward = true,
  }) {
    assert(!progress.isNaN, 'PageFlipGeometry: progress must not be NaN');
    final clampedProgress = progress.clamp(0.0, 1.0);
    final width = size.width;
    final height = size.height;

    final spineX = isDoubleSpread ? width / 2 : 0.0;

    final pageWidth = isDoubleSpread ? width / 2 : width;

    // Flap direction is determined solely by animation direction:
    // forward → flap extends LEFT of foldX (peeling away from right edge)
    // backward → flap extends RIGHT of foldX (growing from spine)
    final flapRightOfFold = !isForward;

    // ── Fold line position ──────────────────────────────────────────────────
    // Double-spread: foldX moves across the spread between the edges/spine.
    // Single forward: foldX moves right→left (crease).
    // Single backward: foldX moves left→right (crease).
    final double foldX;
    if (!isForward) {
      foldX = pageWidth * (1.0 - clampedProgress);
    } else {
      foldX = width - (pageWidth * clampedProgress);
    }

    // ── Rotation angle ──────────────────────────────────────────────────────
    // Compute flap material width early — needed for both angle limits and flaps.
    // Double: flapMaterialWidth is the distance from foldX to the page edge.
    final flapMaterialWidth = !isForward
        ? pageWidth * (1.0 - clampedProgress)
        : pageWidth * clampedProgress;

    final angleT = math.pow(clampedProgress, 0.82).toDouble();
    final angleProfile = math.sin(angleT * math.pi);
    final baseAngle = height <= 0
        ? 0.0
        : (touchOffset.dy / height - 0.5) * _kAngleScale * angleProfile;

    // Limit angle so the flap stays within page bounds.
    // flapSideWidth: width on the flap side of foldX.
    // revealedSideWidth: width on the opposite side.
    final flapSideWidth = flapMaterialWidth;
    final revealedSideWidth = isForward
        ? (foldX - spineX).clamp(0.0, double.infinity)
        : (pageWidth - foldX).clamp(0.0, double.infinity);
    final limitFlap = math.atan2(flapSideWidth, height / 2);
    final limitRevealed = math.atan2(revealedSideWidth, height / 2);
    final absLimit = math.max(0, math.min(limitFlap, limitRevealed)).toDouble();

    // Invert angle when flap is on the right so top-touch lifts the flap top
    // consistently regardless of which side of foldX the flap sits on.
    final rawAngle = flapRightOfFold ? -baseAngle : baseAngle;
    final angle = clampedProgress <= 0.0 || clampedProgress >= 1.0
        ? 0.0
        : rawAngle.clamp(-absLimit, absLimit);

    // Transformation matrix: hinge at foldX.
    final transform = Matrix4.identity()
      ..multiply(Matrix4.translationValues(foldX, height / 2, 0))
      ..rotateZ(-angle)
      ..multiply(Matrix4.translationValues(-foldX, -height / 2, 0));

    // ── Fold line endpoints ─────────────────────────────────────────────────
    final foldLineTop =
        MatrixUtils.transformPoint(transform, Offset(foldX, -height));
    final foldLineBottom =
        MatrixUtils.transformPoint(transform, Offset(foldX, height * 2));

    // ── Shadow intensity ────────────────────────────────────────────────────
    final shadowIntensity = math.sin(clampedProgress * math.pi);

    // ── Flap dimensions ─────────────────────────────────────────────────────
    final flapVisibleWidth = flapMaterialWidth *
        (_kFlapWidthBase -
            _kFlapWidthModulation * math.sin(clampedProgress * math.pi));

    // flapLeft = leftmost x of the visible flap region.
    // freeEdgeX = x of the lifted page edge (the one the user "holds").
    final double flapLeft;
    final double freeEdgeX;
    if (flapRightOfFold) {
      // Flap extends RIGHT from foldX.
      flapLeft = foldX;
      freeEdgeX = foldX + flapVisibleWidth;
    } else {
      // Flap extends LEFT from foldX.
      flapLeft = foldX - flapVisibleWidth;
      freeEdgeX = flapLeft;
    }

    // Flap edge endpoints (screen-space positions of the free edge).
    final flapEdgeTop =
        MatrixUtils.transformPoint(transform, Offset(freeEdgeX, -height));
    final flapEdgeBottom =
        MatrixUtils.transformPoint(transform, Offset(freeEdgeX, height * 2));

    // ── Fold curvature ──────────────────────────────────────────────────────
    final curvatureAmount = math.sin(clampedProgress * math.pi);
    final curveDirection = flapRightOfFold ? -1.0 : 1.0;
    final curveOffset = curvatureAmount * pageWidth * 0.04 * curveDirection;
    final foldCurveControl = MatrixUtils.transformPoint(
      transform,
      Offset(foldX - curveOffset, height / 2),
    );
    final flapCurveControl = MatrixUtils.transformPoint(
      transform,
      Offset(freeEdgeX - curveOffset, height / 2),
    );

    return PageFlipGeometry._(
      progress: clampedProgress,
      isRightToLeft: isRightToLeft,
      touchOffset: touchOffset,
      size: size,
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
      spineX: spineX,
      foldX: foldX,
      angle: angle,
      transform: transform,
      foldLineTop: foldLineTop,
      foldLineBottom: foldLineBottom,
      shadowIntensity: shadowIntensity,
      flapVisibleWidth: flapVisibleWidth,
      flapRightOfFold: flapRightOfFold,
      flapLeft: flapLeft,
      freeEdgeX: freeEdgeX,
      flapEdgeTop: flapEdgeTop,
      flapEdgeBottom: flapEdgeBottom,
      curvatureAmount: curvatureAmount,
      curveOffset: curveOffset,
      foldCurveControl: foldCurveControl,
      flapCurveControl: flapCurveControl,
    );
  }

  /// Private constructor that receives all pre-computed values from [PageFlipGeometry].
  PageFlipGeometry._({
    required this.progress,
    required this.isRightToLeft,
    required this.touchOffset,
    required this.size,
    required this.isDoubleSpread,
    required this.isForward,
    required this.spineX,
    required this.foldX,
    required this.angle,
    required this.transform,
    required this.foldLineTop,
    required this.foldLineBottom,
    required this.shadowIntensity,
    required this.flapVisibleWidth,
    required this.flapRightOfFold,
    required this.flapLeft,
    required this.freeEdgeX,
    required this.flapEdgeTop,
    required this.flapEdgeBottom,
    required this.curvatureAmount,
    required this.curveOffset,
    required this.foldCurveControl,
    required this.flapCurveControl,
  });

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
  final double spineX;

  /// X-coordinate of the paper fold hinge.
  final double foldX;

  /// Fold rotation angle in radians.
  final double angle;

  /// Transformation matrix for the flipping flap.
  final Matrix4 transform;

  /// Top endpoint of the fold line (extended for clean clipping).
  final Offset foldLineTop;

  /// Bottom endpoint of the fold line (extended for clean clipping).
  final Offset foldLineBottom;

  /// Shadow intensity (0.0 to 1.0), peaking mid-animation.
  final double shadowIntensity;

  /// Visible width of the flap after foreshortening.
  final double flapVisibleWidth;

  /// Whether the flap extends to the RIGHT of foldX (true) or LEFT (false).
  final bool flapRightOfFold;

  /// Left edge X-coordinate of the flap.
  final double flapLeft;

  /// Free edge X-coordinate of the flap (the lifted page edge).
  final double freeEdgeX;

  /// Top endpoint of the flap edge.
  final Offset flapEdgeTop;

  /// Bottom endpoint of the flap edge.
  final Offset flapEdgeBottom;

  /// Normalised amount of 2D curvature applied (0.0 to 1.0).
  final double curvatureAmount;

  /// Local space horizontal offset for the bezier control points.
  final double curveOffset;

  /// Bezier control point for the curved fold line in global space.
  final Offset foldCurveControl;

  /// Bezier control point for the curved flap edge in global space.
  final Offset flapCurveControl;
}
