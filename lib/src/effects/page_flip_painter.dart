import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/effects/page_flip_geometry.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

/// PERFORMANCE CRITICAL: This painter is called 60 times per second during animation.
class PageFlipPainter extends CustomPainter {
  /// Creates a [PageFlipPainter] with the given animation state.
  // Note: not const because non-final caching fields require mutable state.
  PageFlipPainter({
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

    /// True if rendering for a dual spread book.
    this.isDoubleSpread = false,

    /// True if we are flipping forward (renders geometry).
    this.isForward = true,

    /// True if the actual transition is forward (for correct opacity/shading).
    bool? isActualForward,

    /// The device pixel ratio for scaling masks.
    this.devicePixelRatio = 1.0,

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

    /// Pre-captured settle-phase snapshot (destination page content).
    ///
    /// Used during Phase 3 (progress 0.85-0.95) to show destination content
    /// instead of the peeled page content. Null = fall back to [flapFrontImage].
    this.flapFrontSettleImage,

    /// Source rect within [flapFrontSettleImage] for settle-phase content.
    this.flapFrontSettleSrcRect,

    /// Pre-captured snapshot for 2.5D page back content (double-spread only).
    this.flapBackImage,

    /// Source rect within [flapBackImage] for the mirrored back texture.
    this.flapBackSrcRect,

    /// Retained for source compatibility; no-op for the direct verso mesh.
    this.flapBackStrength = 0.0,

    /// Retained for source compatibility; no-op for the direct verso mesh.
    this.doubleSpreadMidFoldBleed = 0.0,

    /// Single-page only: opacity of the peeled page's own content while it is
    /// the back-facing side mid-flip (1.0 = crisp, lower = faint bleed-through).
    this.singlePageBackContentOpacity = 0.35,

    /// Whether single-page turns may reveal the destination before finalizing.
    this.enableSinglePageSettleReveal = true,

    /// Pre-computed geometry shared with clippers (avoids redundant construction).
    this.geo,

    /// Performance profile to control mesh density and shadows.
    this.performanceProfile = DevicePerformanceProfile.medium,
  }) : isActualForward = isActualForward ?? isForward;

  /// Normalised flip progress from 0.0 to 1.0.
  final double progress;

  /// Whether the flip direction is right-to-left.
  final bool isRightToLeft;

  /// Touch offset used to compute the fold angle.
  final Offset touchOffset;

  /// The color of the paper back (flipping page's back side).
  final Color paperBackColor;

  /// How much the paper appears translucent at mid-flip (0.0–1.0).
  final double thinPaperStrength;

  /// How much the next page content shows through at end of flip (0.0–1.0).
  final double endRevealStrength;

  /// True if rendering for a dual spread book.
  final bool isDoubleSpread;

  /// True if we are flipping forward (geometry direction).
  final bool isForward;

  /// True if the actual transition is forward.
  final bool isActualForward;

  /// The device pixel ratio for scaling masks.
  final double devicePixelRatio;

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

  /// Pre-captured settle-phase snapshot (destination page content).
  final ui.Image? flapFrontSettleImage;

  /// Source rect within [flapFrontSettleImage] for settle-phase content.
  final Rect? flapFrontSettleSrcRect;

  /// Pre-captured snapshot for 2.5D page back content (double-spread only).
  final ui.Image? flapBackImage;

  /// Source rect within [flapBackImage] for the mirrored back texture.
  final Rect? flapBackSrcRect;

  /// Retained for source compatibility; no-op for the direct verso mesh.
  final double flapBackStrength;

  /// Retained for source compatibility; no-op for the direct verso mesh.
  final double doubleSpreadMidFoldBleed;

  /// Single-page only: opacity of the peeled page's own content while it is the
  /// back-facing side mid-flip.
  ///
  /// Real thin Bible (India) paper shows the printed text only faintly from the
  /// reverse side. Single-page mode keeps the flipping page's content fully
  /// visible the whole turn (it has no blank back), so at the default `1.0` the
  /// peeled side reads as crisp, fully-printed text. Lowering this dims the
  /// peeled content toward the paper colour during the peel (NOT during the
  /// late settle reveal of the destination page), simulating a sheet of paper
  /// laid over the back so the reverse text bleeds through faintly.
  final double singlePageBackContentOpacity;

  /// Whether a single-page turn may reveal its destination before finalizing.
  final bool enableSinglePageSettleReveal;

  /// Pre-computed geometry (avoids redundant construction in paint).
  final PageFlipGeometry? geo;

  /// Performance profile to control mesh density and shadows.
  final DevicePerformanceProfile performanceProfile;

  // Edge-fade shader fields: cache at instance level across paint() calls.
  // CustomPainter is reallocated every build frame, but within a single paint()
  // call both edge and fold shaders are created once and reused inline.
  // No static cache needed — LinearGradient.createShader() for simple 2-stop
  // gradients is a lightweight Impeller operation (~microseconds).

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= kFlipProgressEpsilon ||
        progress >= 1.0 - kFlipProgressEpsilon) {
      return;
    }

    // Use pre-computed geo when available; otherwise construct here
    // (backward compatible when geo is not passed).
    final g = geo ??
        PageFlipGeometry(
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
    final verticalPaintBleed =
        g.angle.abs() > 0.0001 && size.height > 0 ? size.height : 0.0;

    // Eased onset for the discrete fold/gutter/contact shadows. `sin(progress·π)`
    // (g.shadowIntensity) alone snaps these on the instant a turn begins, which
    // reads as a shadow popping into the middle of a two-page spread. Multiplying
    // only these shadow alphas by the envelope keeps the flap's own curl shading
    // (which uses g.shadowIntensity directly) untouched. 1.0 across the plateau,
    // so mid-flip intensity is unchanged.
    final shadowOnset = flipShadowOnset(progress);

    canvas.save();
    if (verticalPaintBleed > 0) {
      canvas.clipRect(Offset.zero & size);
    }

    // Clip to flap region in SCREEN space (before canvas transform) so the
    // clip exactly matches Layer 2's stationary clip along the same fold line,
    // preventing the seam where wrong content shows through.
    final flapPaintRect = buildFlapPaintBoundsLocal(
      g,
      verticalBleed: verticalPaintBleed,
    );
    final flapClipPath = buildFlapScreenClipPath(g);

    canvas.clipPath(flapClipPath);

    // Overall flap opacity modulation (thin paper + end reveal).
    // saveLayer composites everything inside at reduced opacity so the
    // underlying page content shows through — like real translucent paper.
    //
    // SINGLE-PAGE MODE IS EXEMPT. Under the flap sits the STATIONARY current
    // page in its original, un-mirrored position; compositing the whole flap
    // (opaque paper underlay included) at partial alpha lets that page bleed
    // through in place. The result is three hard vertical bands — full-bright
    // middle | washed flap | crisp revealed page — that read as three stacked
    // sheets of glass instead of one turning page. Worst on medium/low
    // profiles, whose flap shows no mesh content mid-flip, so the "wash" is a
    // naked paper veil over the middle layer. Thin-paper feel in single mode
    // is already conveyed by [singlePageBackContentOpacity] (the flap's OWN
    // mirrored back-bleed); the sheet itself must stay opaque.
    final isLowProfile = performanceProfile == DevicePerformanceProfile.low;
    final suppressTranslucency = isLowProfile || !isDoubleSpread;
    final flapAlpha = flapOpacityModulator(
      progress,
      thinPaperStrength: suppressTranslucency ? 0.0 : thinPaperStrength,
      endRevealStrength: suppressTranslucency ? 0.0 : endRevealStrength,
      isForward: isActualForward,
    );
    final needsLayer = flapAlpha < 0.995;
    var didSaveLayer = false;
    if (needsLayer) {
      final screenBounds = Offset.zero & size;
      final intersection = flapClipPath.getBounds().intersect(screenBounds);
      final layerBounds =
          intersection.isEmpty ? screenBounds : intersection.inflate(2);
      canvas.saveLayer(
        layerBounds,
        Paint()..color = Colors.white.withValues(alpha: flapAlpha),
      );
      didSaveLayer = true;
    }

    canvas.transform(g.transform.storage);

    // Layer 1: Paper back underlay, then flap-front texture with late reveal.
    _drawPaperUnderlay(canvas, flapPaintRect);

    _drawFlapContentMesh(canvas, g, flapPaintRect, size);

    _drawEdgeFoldMasks(canvas, g, isPaperDark);

    _drawBendShading(canvas, g, flapPaintRect, isPaperDark);

    _drawFreeEdgeHighlight(canvas, g, isPaperDark);

    _drawFoldAccent(canvas, g, isPaperDark, g.shadowIntensity);

    if (didSaveLayer) canvas.restore();

    canvas.restore();

    _drawCreaseShadow(canvas, g, size, isPaperDark, shadowOnset);

    _drawContactShadow(canvas, g, size, isPaperDark, shadowOnset);

    _drawStationaryShadow(canvas, g, size, isPaperDark, shadowOnset, verticalPaintBleed);

    _drawCenterGutter(canvas, g, size, isPaperDark, shadowOnset);
  }

  void _drawCenterGutter(
    Canvas canvas,
    PageFlipGeometry g,
    Size size,
    bool isPaperDark,
    double shadowOnset,
  ) {
    if (!isDoubleSpread || progress <= 0) return;

    final shadowColor = discreteShadowTone(isPaperDark: isPaperDark);
    final shadowBlend = isPaperDark ? BlendMode.screen : BlendMode.multiply;
    final isLowProfileGutter =
        performanceProfile == DevicePerformanceProfile.low;
    final gutterPeak =
        (isPaperDark ? 0.06 : 0.12) * g.shadowIntensity * shadowOnset;

    final gutterScale = glowBandWidthScale(isPaperDark: isPaperDark);
    final flipSideWidth = 18.0 * gutterScale;
    final stationarySideWidth = 13.0 * gutterScale;

    void drawGutterSide(double outward) {
      if (gutterPeak <= 0.003 || outward == 0) return;
      final outerX = g.spineX + outward;
      final left = math.min(g.spineX, outerX);
      final right = math.max(g.spineX, outerX);
      if (right - left < 0.5) return;
      final rect = Rect.fromLTRB(left, 0, right, size.height);
      canvas.save();
      canvas.clipRect(rect);
      final paint = Paint()..blendMode = shadowBlend;
      if (isLowProfileGutter) {
        paint.color = shadowColor.withValues(alpha: gutterPeak * 0.5);
      } else {
        final peakAtLeft = outward > 0;
        paint.shader = LinearGradient(
          begin: peakAtLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: peakAtLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            shadowColor.withValues(alpha: gutterPeak),
            shadowColor.withValues(alpha: 0),
          ],
        ).createShader(rect);
      }
      canvas.drawRect(rect, paint);
      canvas.restore();
    }

    drawGutterSide(g.isForward ? flipSideWidth : -flipSideWidth);
    drawGutterSide(g.isForward ? -stationarySideWidth : stationarySideWidth);
  }

  void _drawFoldAccent(
    Canvas canvas,
    PageFlipGeometry g,
    bool isPaperDark,
    double bendStrength,
  ) {
    if (!isDoubleSpread ||
        bendStrength <= 0.005 ||
        performanceProfile == DevicePerformanceProfile.low) {
      return;
    }
    final foldDarkenAlign =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final freeDarkenAlign =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final foldDarkenBlend =
        isPaperDark ? BlendMode.screen : BlendMode.multiply;
    final foldDarkenColor = isPaperDark ? Colors.white : Colors.black;
    final foldShadow = (isPaperDark ? 0.02 : 0.05) * bendStrength;
    final foldFadeWidth = foldMaskWidth(
      isPaperDark: isPaperDark,
      devicePixelRatio: devicePixelRatio,
    );
    final foldDarkenWidth = math
        .min(
          g.flapVisibleWidth,
          math.max(foldFadeWidth * 1.5, g.flapVisibleWidth * 0.28),
        )
        .toDouble();
    final foldDarkenPath = buildCurvedFlapBoundaryStripPath(
      g,
      atFold: true,
      width: foldDarkenWidth,
    );
    final foldDarkenBounds = foldDarkenPath.getBounds();
    if (!foldDarkenBounds.isEmpty) {
      canvas.drawPath(
        foldDarkenPath,
        Paint()
          ..blendMode = foldDarkenBlend
          ..shader = LinearGradient(
            begin: foldDarkenAlign,
            end: freeDarkenAlign,
            colors: [
              foldDarkenColor.withValues(alpha: foldShadow),
              foldDarkenColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ).createShader(foldDarkenBounds),
      );
    }
  }

  void _drawContactShadow(
    Canvas canvas,
    PageFlipGeometry g,
    Size size,
    bool isPaperDark,
    double shadowOnset,
  ) {
    if (g.shadowIntensity <= 0.02 ||
        performanceProfile == DevicePerformanceProfile.low ||
        g.flapVisibleWidth <= 4) {
      return;
    }
    final isHighContact = performanceProfile == DevicePerformanceProfile.high;
    final liftGain = freeEdgeContactLiftGain(
      profile: performanceProfile,
      isDoubleSpread: isDoubleSpread,
    );
    final contactSpread = 1.0 + liftGain * g.shadowIntensity;
    final contactWidth =
        kFreeEdgeShadowWidth * contactSpread * g.shadowIntensity;
    final contactAlpha = (isPaperDark ? 0.05 : 0.10) *
        (isDoubleSpread ? (isHighContact ? 1.25 : 1.08) : 1.0) *
        g.shadowIntensity *
        shadowOnset;
    if (contactAlpha > 0.008 && contactWidth > 0.5) {
      final contactPath = buildCurvedFreeEdgeShadowPath(
        g,
        shadowWidth: contactWidth,
      );
      final contactBounds = contactPath.getBounds();
      if (!contactBounds.isEmpty) {
        canvas.save();
        final contactClip = isForward
            ? buildStationaryPageClipPath(size, g)
            : buildOpenPageClipPath(size, g);
        canvas.clipPath(contactClip);
        canvas.transform(g.transform.storage);

        final begin =
            g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
        final end =
            g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
        final contactColor = discreteShadowTone(isPaperDark: isPaperDark);
        final contactBlend =
            isPaperDark ? BlendMode.screen : BlendMode.multiply;
        canvas.drawPath(
          contactPath,
          Paint()
            ..blendMode = contactBlend
            ..shader = LinearGradient(
              begin: begin,
              end: end,
              colors: isDoubleSpread
                  ? <Color>[
                      contactColor.withValues(alpha: contactAlpha),
                      contactColor.withValues(alpha: contactAlpha * 0.4),
                      contactColor.withValues(alpha: 0),
                    ]
                  : <Color>[
                      contactColor.withValues(alpha: contactAlpha),
                      contactColor.withValues(alpha: 0),
                    ],
              stops: isDoubleSpread ? const <double>[0, 0.45, 1] : null,
            ).createShader(contactBounds),
        );
        canvas.restore();
      }
    }
  }

  void _drawStationaryShadow(
    Canvas canvas,
    PageFlipGeometry g,
    Size size,
    bool isPaperDark,
    double shadowOnset,
    double verticalPaintBleed,
  ) {
    if (!isRightToLeft || !isDoubleSpread) return;

    canvas.save();
    final stationaryShadowClip = isForward
        ? buildStationaryPageClipPath(size, g)
        : buildOpenPageClipPath(size, g);
    canvas.clipPath(stationaryShadowClip);
    canvas.transform(g.transform.storage);

    final stationaryWidth = kStationaryShadowWidth *
        glowBandWidthScale(isPaperDark: isPaperDark) *
        g.shadowIntensity;
    final stationaryAlpha =
        (isPaperDark ? 0.045 : 0.06) * g.shadowIntensity * shadowOnset;
    if (stationaryAlpha > 0.01 && stationaryWidth > 1) {
      final stationaryRect = g.flapRightOfFold
          ? Rect.fromLTWH(
              g.foldX,
              -verticalPaintBleed,
              stationaryWidth,
              size.height + verticalPaintBleed * 2,
            )
          : Rect.fromLTWH(
              g.foldX - stationaryWidth,
              -verticalPaintBleed,
              stationaryWidth,
              size.height + verticalPaintBleed * 2,
            );
      final stationaryBegin =
          g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
      final stationaryEnd =
          g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;

      final shadowColor = discreteShadowTone(isPaperDark: isPaperDark);
      final shadowBlend = isPaperDark ? BlendMode.screen : BlendMode.multiply;

      if (performanceProfile == DevicePerformanceProfile.low) {
        canvas.drawRect(
          stationaryRect,
          Paint()
            ..blendMode = shadowBlend
            ..color = shadowColor.withValues(alpha: stationaryAlpha * 0.42),
        );
      } else {
        canvas.drawRect(
          stationaryRect,
          Paint()
            ..blendMode = shadowBlend
            ..shader = LinearGradient(
              begin: stationaryBegin,
              end: stationaryEnd,
              colors: [
                shadowColor.withValues(alpha: stationaryAlpha),
                shadowColor.withValues(alpha: 0),
              ],
            ).createShader(stationaryRect),
        );
      }
    }
    canvas.restore();
  }

  void _drawBendShading(
    Canvas canvas,
    PageFlipGeometry g,
    Rect flapPaintRect,
    bool isPaperDark,
  ) {
    final bendStrength = g.shadowIntensity;
    if (bendStrength <= 0.005 ||
        performanceProfile == DevicePerformanceProfile.low) {
      return;
    }
    final foldAlign = g.flapRightOfFold
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final freeAlign =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;

    final highlightBoost =
        isDoubleSpread && performanceProfile == DevicePerformanceProfile.high
            ? 1.35
            : 1.0;
    final highlightTone = flapHighlightTone(isPaperDark: isPaperDark);
    final highlightPeak = flapHighlightPeakBase(isPaperDark: isPaperDark) *
        highlightBoost *
        bendStrength;
    final highlightMid = flapHighlightMidBase(isPaperDark: isPaperDark) *
        highlightBoost *
        bendStrength;
    canvas.drawRect(
      flapPaintRect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: freeAlign,
          end: foldAlign,
          colors: [
            highlightTone.withValues(alpha: 0),
            highlightTone.withValues(alpha: highlightPeak),
            highlightTone.withValues(alpha: highlightMid),
            highlightTone.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.38, 0.60, 0.78],
        ).createShader(flapPaintRect),
    );

    if (performanceProfile == DevicePerformanceProfile.high) {
      final cylinderColor = discreteShadowTone(isPaperDark: isPaperDark);
      final cylinderBlend =
          isPaperDark ? BlendMode.screen : BlendMode.multiply;
      final cylinderAlpha = isDoubleSpread
          ? (isPaperDark ? 0.09 : 0.15) * bendStrength
          : (isPaperDark ? 0.05 : 0.08) * bendStrength;
      final cylinderColors = isDoubleSpread
          ? <Color>[
              cylinderColor.withValues(alpha: cylinderAlpha),
              cylinderColor.withValues(alpha: cylinderAlpha * 0.5),
              cylinderColor.withValues(alpha: 0),
              cylinderColor.withValues(alpha: 0),
            ]
          : <Color>[
              cylinderColor.withValues(alpha: cylinderAlpha),
              cylinderColor.withValues(alpha: 0),
              cylinderColor.withValues(alpha: 0),
            ];
      final cylinderStops = isDoubleSpread
          ? const <double>[0, 0.28, 0.62, 1]
          : const <double>[0, 0.45, 1];
      canvas.drawRect(
        flapPaintRect,
        Paint()
          ..blendMode = cylinderBlend
          ..shader = LinearGradient(
            begin: freeAlign,
            end: foldAlign,
            colors: cylinderColors,
            stops: cylinderStops,
          ).createShader(flapPaintRect),
      );
    }
  }

  void _drawCreaseShadow(
    Canvas canvas,
    PageFlipGeometry g,
    Size size,
    bool isPaperDark,
    double shadowOnset,
  ) {
    canvas.save();

    if (!isDoubleSpread) {
      canvas.clipRect(Offset.zero & size);
      canvas.transform(g.transform.storage);

      final creaseFoldFadeWidth = foldMaskWidth(
        isPaperDark: isPaperDark,
        devicePixelRatio: devicePixelRatio,
      );
      final revealedWidth = kCreaseShadowWidth * 1.8 * g.shadowIntensity;
      final flapWidth = math.min(
        g.flapVisibleWidth,
        math.max(creaseFoldFadeWidth, kCreaseFlapSideWidth) * g.shadowIntensity,
      );
      final peakOpacity =
          (isPaperDark ? 0.055 : 0.13) * g.shadowIntensity * shadowOnset;
      if (peakOpacity > 0.008 && revealedWidth > 1 && flapWidth > 0.5) {
        final density = flapMeshDensityForPerformance(performanceProfile);
        final creaseMesh = buildCurvedCreaseValleyMesh(
          g,
          flapSideWidth: flapWidth,
          revealedSideWidth: revealedWidth,
          color: discreteShadowTone(isPaperDark: isPaperDark),
          peakOpacity: peakOpacity,
          segments: density.segments,
        );
        try {
          canvas.drawVertices(
            creaseMesh,
            BlendMode.dst,
            Paint()
              ..blendMode = isPaperDark ? BlendMode.screen : BlendMode.multiply,
          );
        } finally {
          creaseMesh.dispose();
        }
      }

      canvas.restore();
    } else {
      final shadowClipPath = isForward
          ? buildOpenPageClipPath(size, g)
          : buildStationaryPageClipPath(size, g);
      canvas.clipPath(shadowClipPath);
      canvas.transform(g.transform.storage);

      final shadowWidth = kCreaseShadowWidth *
          glowBandWidthScale(isPaperDark: isPaperDark) *
          g.shadowIntensity;
      final revealedAlpha =
          (isPaperDark ? 0.055 : 0.15) * g.shadowIntensity * shadowOnset;
      if (revealedAlpha > 0.01 && shadowWidth > 1) {
        final shadowPath = buildCurvedFoldShadowPath(
          g,
          isForward: isForward,
          shadowWidth: shadowWidth,
        );
        final shadowBounds = shadowPath.getBounds();

        final beginAlign =
            isForward ? Alignment.centerLeft : Alignment.centerRight;
        final endAlign =
            isForward ? Alignment.centerRight : Alignment.centerLeft;

        final shadowColor = discreteShadowTone(isPaperDark: isPaperDark);
        final shadowBlend = isPaperDark ? BlendMode.screen : BlendMode.srcOver;

        if (performanceProfile == DevicePerformanceProfile.low) {
          canvas.drawPath(
            shadowPath,
            Paint()
              ..blendMode = shadowBlend
              ..color = shadowColor.withValues(alpha: revealedAlpha * 0.42),
          );
        } else {
          canvas.drawPath(
            shadowPath,
            Paint()
              ..blendMode = shadowBlend
              ..shader = LinearGradient(
                begin: beginAlign,
                end: endAlign,
                colors: [
                  shadowColor.withValues(alpha: revealedAlpha),
                  shadowColor.withValues(alpha: revealedAlpha * 0.45),
                  shadowColor.withValues(alpha: 0),
                ],
                stops: kCreaseValleyStops,
              ).createShader(shadowBounds),
          );

          final ambientWidth = shadowWidth * 1.8;
          final ambientPath = buildCurvedFoldShadowPath(
            g,
            isForward: isForward,
            shadowWidth: ambientWidth,
          );
          final ambientAlpha =
              (isPaperDark ? 0.015 : 0.035) * g.shadowIntensity * shadowOnset;
          canvas.drawPath(
            ambientPath,
            Paint()
              ..blendMode = shadowBlend
              ..shader = LinearGradient(
                begin: beginAlign,
                end: endAlign,
                colors: [
                  shadowColor.withValues(alpha: ambientAlpha),
                  shadowColor.withValues(alpha: 0),
                ],
                stops: const [0.0, 1.0],
              ).createShader(ambientPath.getBounds()),
          );
        }
      }

      canvas.restore();
    }
  }

  void _drawFlapContentMesh(
    Canvas canvas,
    PageFlipGeometry g,
    Rect flapPaintRect,
    Size size,
  ) {
    final normalizedProgress =
        normalizedFlapProgress(progress, isForward: isActualForward);
    final isSettlePhase = (isDoubleSpread || enableSinglePageSettleReveal) &&
        isFlapSettlePhase(
          progress,
          isForward: isActualForward,
          revealStart: flapContentRevealStart,
        );
    final usesLightweightBackFace =
        performanceProfile != DevicePerformanceProfile.high;
    final skipBackFacingMesh =
        !isDoubleSpread && usesLightweightBackFace && !isSettlePhase;

    final hasFlapTexture = flapFrontImage != null && flapFrontSrcRect != null;
    if (!hasFlapTexture) return;

    final contentReveal = flapFrontContentRevealOpacity(
      progress,
      fadeOutEnd: flapContentFadeOutEnd,
      revealStart: flapContentRevealStart,
      revealEnd: flapContentRevealEnd,
      isForward: isActualForward,
      isDoubleSpread: isDoubleSpread,
      keepSinglePageContentVisible:
          performanceProfile == DevicePerformanceProfile.high,
      enableSinglePageSettleReveal: enableSinglePageSettleReveal,
      doubleSpreadMidFoldBleed: doubleSpreadMidFoldBleed,
    );
    if (contentReveal <= 0.001) return;

    final useSettle = isSettlePhase &&
        flapFrontSettleImage != null &&
        flapFrontSettleSrcRect != null;
    final srcImage = useSettle ? flapFrontSettleImage! : flapFrontImage!;
    final srcRect = useSettle ? flapFrontSettleSrcRect! : flapFrontSrcRect!;

    if (g.flapVisibleWidth < 12.0 || skipBackFacingMesh) return;

    final density = flapMeshDensityForPerformance(performanceProfile);

    final mesh = buildFlapContentMesh(
      size: size,
      foldX: g.foldX,
      flapLeft: g.freeEdgeX,
      curveOffset: g.curveOffset,
      srcRect: srcRect,
      segments: density.segments,
      columns: density.columns,
      flipHorizontal: !isDoubleSpread || !isForward,
    );
    try {
      canvas.drawVertices(
        mesh,
        BlendMode.srcOver,
        Paint()
          ..shader = ui.ImageShader(
            srcImage,
            ui.TileMode.clamp,
            ui.TileMode.clamp,
            identityMatrixStorage,
          )
          ..filterQuality = FilterQuality.medium,
      );
    } finally {
      mesh.dispose();
    }

    final backDim = (!isDoubleSpread && singlePageBackContentOpacity < 1.0)
        ? enableSinglePageSettleReveal
            ? singlePageBackDim(
                normalizedProgress,
                backOpacity: singlePageBackContentOpacity.clamp(0.0, 1.0),
                revealStart: flapContentRevealStart,
                revealEnd: flapContentRevealEnd,
              )
            : singlePageBackContentOpacity.clamp(0.0, 1.0)
        : 1.0;
    final effectiveReveal = contentReveal * backDim;
    final fadeAlpha = (1.0 - effectiveReveal).clamp(0.0, 1.0);
    if (fadeAlpha > 0.005) {
      canvas.drawRect(
        flapPaintRect,
        Paint()
          ..blendMode = BlendMode.srcOver
          ..color = paperBackColor.withValues(alpha: fadeAlpha),
      );
    }
  }

  void _drawPaperUnderlay(Canvas canvas, Rect flapPaintRect) {
    canvas.drawRect(
      flapPaintRect,
      Paint()
        ..color = resolvePaperUnderlayColor(paperBackColor, paperOpacity),
    );
  }

  void _drawFreeEdgeHighlight(
    Canvas canvas,
    PageFlipGeometry g,
    bool isPaperDark,
  ) {
    if (g.shadowIntensity <= 0.02 ||
        performanceProfile == DevicePerformanceProfile.low) {
      return;
    }
    final edgeFadeBegin =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final edgeFadeEnd =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final edgeHighlightWidth = math.min(
      g.flapVisibleWidth,
      (isPaperDark ? 2.0 : 2.5) * (devicePixelRatio >= 2.0 ? 1.25 : 1.0),
    );
    final edgeHighlightPath = buildCurvedFlapBoundaryStripPath(
      g,
      atFold: false,
      width: edgeHighlightWidth,
    );
    final edgeHighlightBounds = edgeHighlightPath.getBounds();
    if (!edgeHighlightBounds.isEmpty) {
      final highlightTone = flapHighlightTone(isPaperDark: isPaperDark);
      final highlightAlpha = (isPaperDark ? 0.06 : 0.16) * g.shadowIntensity;
      canvas.drawPath(
        edgeHighlightPath,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: edgeFadeBegin,
            end: edgeFadeEnd,
            colors: [
              highlightTone.withValues(alpha: highlightAlpha),
              highlightTone.withValues(alpha: 0),
            ],
          ).createShader(edgeHighlightBounds),
      );
    }
  }

  void _drawEdgeFoldMasks(
    Canvas canvas,
    PageFlipGeometry g,
    bool isPaperDark,
  ) {
    final maskPeak = edgeMaskPeakOpacity(isPaperDark: isPaperDark);

    // Edge-fade: mask partial-text artifacts at the flap's free edge.
    final edgeFadeWidth = edgeMaskWidth(
      isPaperDark: isPaperDark,
      devicePixelRatio: devicePixelRatio,
    );
    final edgeFadeBegin =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final edgeFadeEnd =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final edgeFadePath = buildCurvedFlapBoundaryStripPath(
      g,
      atFold: false,
      width: edgeFadeWidth,
    );
    final edgeFadeBounds = edgeFadePath.getBounds();
    if (!edgeFadeBounds.isEmpty) {
      canvas.drawPath(
        edgeFadePath,
        Paint()
          ..shader = LinearGradient(
            begin: edgeFadeBegin,
            end: edgeFadeEnd,
            colors: [
              paperBackColor.withValues(alpha: maskPeak),
              paperBackColor.withValues(alpha: 0),
            ],
          ).createShader(edgeFadeBounds),
      );
    }

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    final foldFadeWidth = foldMaskWidth(
      isPaperDark: isPaperDark,
      devicePixelRatio: devicePixelRatio,
    );
    final foldFadeBegin =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final foldFadeEnd =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final foldFadePath = buildCurvedFlapBoundaryStripPath(
      g,
      atFold: true,
      width: foldFadeWidth,
    );
    final foldFadeBounds = foldFadePath.getBounds();
    if (!foldFadeBounds.isEmpty) {
      canvas.drawPath(
        foldFadePath,
        Paint()
          ..shader = LinearGradient(
            begin: foldFadeBegin,
            end: foldFadeEnd,
            colors: [
              paperBackColor.withValues(alpha: maskPeak),
              paperBackColor.withValues(alpha: 0),
            ],
          ).createShader(foldFadeBounds),
      );
    }
  }

  /// Only repaints when animation-critical values change.
  @override
  bool shouldRepaint(covariant PageFlipPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.touchOffset != touchOffset ||
      oldDelegate.isRightToLeft != isRightToLeft ||
      oldDelegate.paperBackColor != paperBackColor ||
      oldDelegate.isDoubleSpread != isDoubleSpread ||
      oldDelegate.isForward != isForward ||
      oldDelegate.isActualForward != isActualForward ||
      oldDelegate.devicePixelRatio != devicePixelRatio ||
      oldDelegate.paperOpacity != paperOpacity ||
      oldDelegate.flapContentFadeOutEnd != flapContentFadeOutEnd ||
      oldDelegate.thinPaperStrength != thinPaperStrength ||
      oldDelegate.endRevealStrength != endRevealStrength ||
      oldDelegate.flapContentRevealStart != flapContentRevealStart ||
      oldDelegate.flapContentRevealEnd != flapContentRevealEnd ||
      oldDelegate.flapFrontImage != flapFrontImage ||
      oldDelegate.flapFrontSrcRect != flapFrontSrcRect ||
      oldDelegate.flapFrontSettleImage != flapFrontSettleImage ||
      oldDelegate.flapFrontSettleSrcRect != flapFrontSettleSrcRect ||
      oldDelegate.singlePageBackContentOpacity !=
          singlePageBackContentOpacity ||
      oldDelegate.enableSinglePageSettleReveal !=
          enableSinglePageSettleReveal ||
      oldDelegate.performanceProfile != performanceProfile;
}
