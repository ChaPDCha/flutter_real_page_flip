import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_constants.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

// ─── Edge / fold mask parameters ───

/// Peak opacity of the free-edge / fold texture masks (the narrow paper-colour
/// gradients that hide crushed mesh fragments at the flap boundaries).
///
/// On LIGHT paper the mask is paper-over-paper and therefore invisible, so it
/// runs at full opacity to fully hide the crushed edge. On DARK paper (e.g. the
/// pure-black theme) a full-opacity paper strip wipes the light text into a
/// hard vertical "dark band at the paper edge"; holding it below full opacity
/// lets the text bleed through faintly so the edge reads as a soft transition.
double edgeMaskPeakOpacity({required bool isPaperDark}) =>
    isPaperDark ? 0.7 : 1.0;

double edgeMaskWidth({
  required bool isPaperDark,
  double devicePixelRatio = 1.0,
}) =>
    (isPaperDark ? 5.0 : 8.0) * (devicePixelRatio >= 2.0 ? 1.25 : 1.0);

/// Width (px) of the fold-crease texture mask. See [edgeMaskWidth].
double foldMaskWidth({
  required bool isPaperDark,
  double devicePixelRatio = 1.0,
}) =>
    (isPaperDark ? 4.0 : 6.0) * (devicePixelRatio >= 2.0 ? 1.25 : 1.0);

// ─── Highlight / shadow tones ───

/// Tint of the soft centre highlight that catches light on the curling paper.
///
/// `isPaperDark` selects between dark and light paper surfaces: dark paper gets
/// a faint cool ambient tint so near-black stock reads as a real surface; light
/// paper gets a warm paper-white sheen.
Color flapHighlightTone({required bool isPaperDark}) => isPaperDark
    ? const Color(0xFFE8E8F0) // neutral off-white with minimal blue
    : const Color(0xFFFFF4E0); // warm paper white

/// Base peak alpha of the centre highlight (before shadow-intensity scaling).
///
/// Kept intentionally tiny — thin Bible paper is matte, so a strong specular
/// streak would read as glass/plastic. Dark paper is dimmer still.
double flapHighlightPeakBase({required bool isPaperDark}) =>
    isPaperDark ? 0.07 : 0.10;

/// Base mid-band alpha of the centre highlight (before shadow-intensity).
double flapHighlightMidBase({required bool isPaperDark}) =>
    isPaperDark ? 0.04 : 0.06;

/// Colour of the discrete crease/gutter/stationary/contact shadow accents.
///
/// Light paper darkens under a fold, so its accents are black shadow. Dark
/// paper cannot darken further; its accents are painted as light falling onto
/// the sheet instead — and that light must carry the same cool moonlight cast
/// as [flapHighlightTone] so every lit accent on near-black stock reads as one
/// light source. Pure [Colors.white] at these band widths reads as a detached
/// bright line hovering over the page rather than a sheen on its surface.
Color discreteShadowTone({required bool isPaperDark}) =>
    isPaperDark ? const Color(0xFFE8E8F0) : Colors.black;

/// Width multiplier for the discrete glow bands on dark paper.
///
/// A light accent on near-black stock carries far more perceived contrast than
/// the equivalent dark shadow on white paper, so at equal width it reads as a
/// crisp separate line instead of light spreading across the sheet. Widening
/// the band — with its peak alpha lowered at the call sites — turns the accent
/// into a soft moonlit falloff. Light paper keeps 1.0 (shadows already blend).
/// The dark scale keeps the widened crease band (22px → ~35px) within the 36px
/// revealed-shadow layout guard reserved by `conservativeFoldAngleLimit`.
double glowBandWidthScale({required bool isPaperDark}) =>
    isPaperDark ? 1.6 : 1.0;

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
double freeEdgeContactLiftGain({
  required DevicePerformanceProfile profile,
  required bool isDoubleSpread,
}) {
  if (!isDoubleSpread) return 0;
  return profile == DevicePerformanceProfile.high ? 1.3 : 0.55;
}

// ─── Content opacity curves ───

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
  bool enableSinglePageSettleReveal = true,
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

  // Lightweight single-page readers can deliberately keep the flap blank
  // until PageFlipWidget commits the destination page.
  if (!enableSinglePageSettleReveal) return 0;

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

// ─── Flap opacity modulation ───

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
