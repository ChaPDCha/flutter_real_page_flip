part of 'page_flip_engine.dart';

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

    if (g.progress <= kFlipProgressEpsilon) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    if (g.progress >= 1.0 - kFlipProgressEpsilon) {
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

    /// Pre-computed geometry shared with painter (perf optimization).
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

    // The open region follows the visual direction at the exact endpoints.
    // Forward turns finish fully open at progress=1. Backward turns are the
    // reverse animation: they start fully open at progress=1 and finish closed
    // at progress=0. Returning a full rect at BOTH endpoints made the current
    // spread cover the destination for the completed backward frame, followed
    // by an abrupt previous-spread swap during finalization (one-frame flash).
    if (!g.isForward && g.progress <= kFlipProgressEpsilon) {
      return Path();
    }
    if (g.progress <= kFlipProgressEpsilon ||
        g.progress >= 1.0 - kFlipProgressEpsilon) {
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
