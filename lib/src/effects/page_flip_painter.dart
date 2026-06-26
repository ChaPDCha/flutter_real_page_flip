part of 'page_flip_engine.dart';

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

    /// How much the paper appears translucent at mid-flip (0.0–1.0).
    this.thinPaperStrength = 0.0,

    /// How much the next page content shows through at end of flip (0.0–1.0).
    this.endRevealStrength = 0.0,

    /// True if rendering for a dual spread book.
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

    /// Pre-captured settle-phase snapshot (destination page content).
    ///
    /// Used during Phase 3 (progress 0.85-0.95) to show destination content
    /// instead of the peeled page content. Null = fall back to [flapFrontImage].
    this.flapFrontSettleImage,

    /// Source rect within [flapFrontSettleImage] for settle-phase content.
    this.flapFrontSettleSrcRect,

    /// Destination rect for [flapFrontSrcRect] on the canvas (defaults to right page).
    this.flapFrontDestRect,

    /// Pre-captured snapshot for 2.5D page back content (double-spread only).
    this.flapBackImage,

    /// Source rect within [flapBackImage] for the mirrored back texture.
    this.flapBackSrcRect,

    /// How visible the back content is (0.0–1.0, default 0.3).
    /// 0 = disabled, 0.3 = subtle mirror-through-paper effect.
    this.flapBackStrength = 0.0,

    /// Pre-computed geometry shared with clippers (avoids redundant construction).
    this.geo,

    /// Performance profile to control mesh density and shadows.
    this.performanceProfile = DevicePerformanceProfile.high,
  });

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

  /// Pre-captured settle-phase snapshot (destination page content).
  final ui.Image? flapFrontSettleImage;

  /// Source rect within [flapFrontSettleImage] for settle-phase content.
  final Rect? flapFrontSettleSrcRect;

  /// Destination rect for flap front texture (null = legacy right-page mapping).
  final Rect? flapFrontDestRect;

  /// Pre-captured snapshot for 2.5D page back content (double-spread only).
  final ui.Image? flapBackImage;

  /// Source rect within [flapBackImage] for the mirrored back texture.
  final Rect? flapBackSrcRect;

  /// How visible the back content is (0.0–1.0, default 0.3).
  final double flapBackStrength;

  /// Pre-computed geometry (avoids redundant construction in paint).
  final PageFlipGeometry? geo;

  /// Performance profile to control mesh density and shadows.
  final DevicePerformanceProfile performanceProfile;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) {
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

    canvas.save();

    // Clip to flap region in SCREEN space (before canvas transform) so the
    // clip exactly matches Layer 2's stationary clip along the same fold line,
    // preventing the seam where wrong content shows through.
    final flapRect = Rect.fromLTWH(
      g.flapLeft,
      0,
      g.flapVisibleWidth + kSpineRevealOverlapPx,
      size.height,
    );

    canvas.clipPath(buildFlapScreenClipPath(g));

    // Overall flap opacity modulation (thin paper + end reveal).
    // saveLayer composites everything inside at reduced opacity so the
    // underlying page content shows through — like real translucent paper.
    final flapAlpha = flapOpacityModulator(
      progress,
      thinPaperStrength: thinPaperStrength,
      endRevealStrength: endRevealStrength,
      isForward: isForward,
      isDoubleSpread: isDoubleSpread,
    );
    final needsLayer = flapAlpha < 0.995;
    if (needsLayer) {
      canvas.saveLayer(
        null,
        Paint()..color = Colors.white.withValues(alpha: flapAlpha),
      );
    }

    canvas.transform(g.transform.storage);

    // Layer 1: Paper back underlay, then flap-front texture with late reveal.
    final paperPaint = Paint()
      ..color = paperBackColor.withValues(
        alpha: paperOpacity == 1.0
            ? 1.0
            : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0),
      );
    canvas.drawRect(flapRect, paperPaint);

    // Layer 2: 2.5D page back content (double-spread only).
    // Shows the destination page content horizontally mirrored at low opacity,
    // creating the illusion of seeing through thin paper to the back side.
    final hasFlapBack =
        flapBackImage != null && flapBackSrcRect != null && isDoubleSpread;
    if (hasFlapBack && g.flapVisibleWidth >= 8.0) {
      var segments = 16;
      var columns = 4;
      if (performanceProfile == DevicePerformanceProfile.low) {
        segments = 8;
        columns = 1;
      } else if (performanceProfile == DevicePerformanceProfile.medium) {
        segments = 12;
        columns = 2;
      }

      final backMesh = buildFlapContentMesh(
        size: size,
        foldX: g.foldX,
        flapLeft: g.freeEdgeX,
        curveOffset: g.curveOffset,
        srcRect: flapBackSrcRect!,
        segments: segments,
        columns: columns,
        flipHorizontal: true,
      );
      canvas.drawVertices(
        backMesh,
        BlendMode.srcOver,
        Paint()
          ..shader = ui.ImageShader(
            flapBackImage!,
            ui.TileMode.clamp,
            ui.TileMode.clamp,
            _identityMatrixStorage,
          )
          ..filterQuality = FilterQuality.medium,
      );

      // Fade the back content into the paper by flapBackStrength so it looks
      // like a subtle bleed-through rather than a full texture layer.
      final backFadeAlpha = (1.0 - flapBackStrength).clamp(0.0, 1.0);
      if (backFadeAlpha > 0.005) {
        canvas.drawRect(
          flapRect,
          Paint()
            ..blendMode = BlendMode.srcOver
            ..color = paperBackColor.withValues(alpha: backFadeAlpha),
        );
      }
    }

    final hasFlapTexture = flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final contentReveal = flapFrontContentRevealOpacity(
        progress,
        fadeOutEnd: flapContentFadeOutEnd,
        revealStart: flapContentRevealStart,
        revealEnd: flapContentRevealEnd,
        isForward: isForward,
        isDoubleSpread: isDoubleSpread,
      );
      if (contentReveal > 0.001) {
        // Determine which image/rect to use: settle content for Phase 3,
        // regular flap content for Phase 1 (early drag).
        final invertProgress = !isForward;
        final normalizedProgress = invertProgress ? (1.0 - progress) : progress;
        final isSettlePhase = normalizedProgress >= flapContentRevealStart;
        final useSettle = isSettlePhase &&
            flapFrontSettleImage != null &&
            flapFrontSettleSrcRect != null;
        final srcImage = useSettle ? flapFrontSettleImage! : flapFrontImage!;
        final srcRect = useSettle ? flapFrontSettleSrcRect! : flapFrontSrcRect!;

        // Minimum width guard: flap narrower than 8 px compresses the full
        // page texture into garbage. Paper underlay + fade overlay handle
        // this scale — skip the mesh entirely.
        if (g.flapVisibleWidth >= 8.0) {
          // Build a triangle mesh that follows the bezier curves so text and
          // images appear to bend with the paper — not a flat board tilting.
          // 16 vertical segments × 6 horizontal columns (4 interior) with
          // surface bulge creates a convex 3D paper curl effect.
          var segments = 16;
          var columns = 4;
          if (performanceProfile == DevicePerformanceProfile.low) {
            segments = 8;
            columns = 1;
          } else if (performanceProfile == DevicePerformanceProfile.medium) {
            segments = 12;
            columns = 2;
          }

          final mesh = buildFlapContentMesh(
            size: size,
            foldX: g.foldX,
            flapLeft: g.freeEdgeX,
            curveOffset: g.curveOffset,
            srcRect: srcRect,
            segments: segments,
            columns: columns,
          );
          canvas.drawVertices(
            mesh,
            BlendMode.srcOver,
            Paint()
              ..shader = ui.ImageShader(
                srcImage,
                ui.TileMode.clamp,
                ui.TileMode.clamp,
                _identityMatrixStorage,
              )
              ..filterQuality = FilterQuality.medium,
          );

          // Fade mesh away during early fold / late settle using paper-colour
          // overlay so content does not pop in/out harshly.
          final fadeAlpha = (1.0 - contentReveal).clamp(0.0, 1.0);
          if (fadeAlpha > 0.005) {
            canvas.drawRect(
              flapRect,
              Paint()
                ..blendMode = BlendMode.srcOver
                ..color = paperBackColor.withValues(alpha: fadeAlpha),
            );
          }
        }
      }
    }

    // Layer 2–3: Subtle paper-bend shading
    //
    // A gentle highlight across the flap centre and faint darkening at the
    // fold edge. Strong enough to suggest a curved surface, soft enough not
    // to look like the paper is tightly rolled.
    // Fold side vs free-edge side determined by flapRightOfFold.
    final bendStrength = g.shadowIntensity; // 0–1, peaks mid-flip
    if (bendStrength > 0.005 &&
        performanceProfile != DevicePerformanceProfile.low) {
      // Fold-side alignment: where the flap meets the page.
      final foldAlign = g.flapRightOfFold
          ? Alignment.centerLeft // fold on left, flap extends right
          : Alignment.centerRight; // fold on right, flap extends left
      // Free-edge alignment: the lifted page edge.
      final freeAlign =
          g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;

      // Gentle centre highlight (catches light on the bulge).
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: freeAlign,
            end: foldAlign,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.12 * bendStrength),
              Colors.white.withValues(alpha: 0.08 * bendStrength),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.70, 1.0],
          ).createShader(flapRect),
      );

      // Subtle fold-edge darkening.
      final foldShadow = (isPaperDark ? 0.10 : 0.15) * bendStrength;
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            begin: foldAlign,
            end: freeAlign,
            colors: [
              Colors.black.withValues(alpha: foldShadow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25],
          ).createShader(flapRect),
      );
    }

    // Edge-fade: mask partial-text artifacts at the flap's free edge.
    // A ~8 px gradient from paperBackColor → transparent hides stray character
    // fragments at the mesh boundary without affecting visible flap content.
    const double edgeFadeWidth = 8;
    final edgeFadeRect = g.flapRightOfFold
        ? Rect.fromLTWH(
            g.freeEdgeX - edgeFadeWidth,
            0,
            edgeFadeWidth,
            size.height,
          )
        : Rect.fromLTWH(g.flapLeft, 0, edgeFadeWidth, size.height);
    final edgeFadeBegin =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    final edgeFadeEnd =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    canvas.drawRect(
      edgeFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: edgeFadeBegin,
          end: edgeFadeEnd,
          colors: [
            paperBackColor.withValues(alpha: 1),
            Colors.transparent,
          ],
        ).createShader(edgeFadeRect),
    );

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    // As the flap narrows near the fold line, texture pixels compress and
    // create visible fragments. This narrow gradient from paperBackColor →
    // transparent softens the fold boundary edge.
    const double foldFadeWidth = 6;
    final foldFadeRect = g.flapRightOfFold
        ? Rect.fromLTWH(g.foldX, 0, foldFadeWidth, size.height)
        : Rect.fromLTWH(g.foldX - foldFadeWidth, 0, foldFadeWidth, size.height);
    final foldFadeBegin =
        g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
    final foldFadeEnd =
        g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
    canvas.drawRect(
      foldFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: foldFadeBegin,
          end: foldFadeEnd,
          colors: [
            paperBackColor.withValues(alpha: 1),
            Colors.transparent,
          ],
        ).createShader(foldFadeRect),
    );

    if (needsLayer) canvas.restore();

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
      if (performanceProfile == DevicePerformanceProfile.low) {
        canvas.drawRect(
          revealedRect,
          Paint()..color = Colors.black.withValues(alpha: revealedAlpha * 0.5),
        );
      } else {
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
        if (performanceProfile == DevicePerformanceProfile.low) {
          canvas.drawRect(
            stationaryRect,
            Paint()
              ..color = Colors.black.withValues(alpha: stationaryAlpha * 0.5),
          );
        } else {
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
      if (performanceProfile == DevicePerformanceProfile.low) {
        canvas.drawRect(
          spineRect,
          Paint()
            ..blendMode = BlendMode.multiply
            ..color = Colors.black.withValues(alpha: 0.04 * g.shadowIntensity),
        );
      } else {
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
      }
      canvas.restore();
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
      oldDelegate.flapFrontDestRect != flapFrontDestRect ||
      oldDelegate.flapBackImage != flapBackImage ||
      oldDelegate.flapBackSrcRect != flapBackSrcRect ||
      oldDelegate.flapBackStrength != flapBackStrength ||
      oldDelegate.performanceProfile != performanceProfile;
}
