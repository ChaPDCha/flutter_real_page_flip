import 'dart:ui';

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

/// Resolves the effective paper underlay color and alpha for both the widget
/// layer ([PageFlipLayerView]) and the canvas painter ([PageFlipPainter]).
///
/// Dark paper (luminance < 0.20) gets a 1.1x alpha boost so the underlay does
/// not read as a translucent gap over near-black backgrounds.
Color resolvePaperUnderlayColor(Color paperColor, double paperOpacity) {
  final isPaperDark = paperColor.computeLuminance() < 0.20;
  final alpha = paperOpacity == 1.0
      ? 1.0
      : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0);
  return paperColor.withValues(alpha: alpha);
}
