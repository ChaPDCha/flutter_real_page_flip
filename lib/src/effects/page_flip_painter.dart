part of 'page_flip_engine.dart';

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

    /// Single-page only: opacity of the peeled page's own content while it is
    /// the back-facing side mid-flip (1.0 = crisp, lower = faint bleed-through).
    this.singlePageBackContentOpacity = 1.0,

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
    );
    final needsLayer = flapAlpha < 0.995;
    if (needsLayer) {
      canvas.saveLayer(
        flapRect,
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

    final invertProgress = !isForward;
    final normalizedProgress = invertProgress ? (1.0 - progress) : progress;
    final isSettlePhase = normalizedProgress >= flapContentRevealStart;
    final skipEarlyMesh =
        (performanceProfile != DevicePerformanceProfile.high) && !isSettlePhase;

    // Layer 2: 2.5D page back content (double-spread only).
    // Shows the destination page content horizontally mirrored at low opacity,
    // creating the illusion of seeing through thin paper to the back side.
    final hasFlapBack =
        flapBackImage != null && flapBackSrcRect != null && isDoubleSpread;
    if (hasFlapBack && g.flapVisibleWidth >= 8.0 && !skipEarlyMesh) {
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
        final useSettle = isSettlePhase &&
            flapFrontSettleImage != null &&
            flapFrontSettleSrcRect != null;
        final srcImage = useSettle ? flapFrontSettleImage! : flapFrontImage!;
        final srcRect = useSettle ? flapFrontSettleSrcRect! : flapFrontSrcRect!;

        // Minimum width guard: flap narrower than 8 px compresses the full
        // page texture into garbage. Paper underlay + fade overlay handle
        // this scale — skip the mesh entirely.
        // Mesh rendering is also skipped early in the flip on low/medium devices.
        if (g.flapVisibleWidth >= 8.0 && !skipEarlyMesh) {
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
            // Single-page: srcRect is the right-anchored lifted strip. Mirror
            // the UV so the crease edge stays continuous with the page beneath
            // (folded paper reads as a mirror of its front). Double-spread keeps
            // its existing non-mirrored mapping.
            flipHorizontal: !isDoubleSpread,
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
          //
          // Single-page thin-paper bleed-through: while the peeled page is the
          // back-facing side, dim its own content toward the paper colour so
          // the reverse text shows only faintly — like a sheet of paper laid
          // over the back. As the page settles flat it becomes the crisp
          // destination, so the dim eases back to 1.0 *continuously* across the
          // settle window. Gating it on the hard `useSettle` boolean made the
          // overlay's alpha snap off in one frame at the settle boundary — a
          // visible flicker at the binding edge near the end of the swipe.
          // Default opacity 1.0 leaves existing behaviour intact.
          final backDim = (!isDoubleSpread && singlePageBackContentOpacity < 1.0)
              ? singlePageBackDim(
                  normalizedProgress,
                  backOpacity: singlePageBackContentOpacity.clamp(0.0, 1.0),
                  revealStart: flapContentRevealStart,
                  revealEnd: flapContentRevealEnd,
                )
              : 1.0;
          final effectiveReveal = contentReveal * backDim;
          final fadeAlpha = (1.0 - effectiveReveal).clamp(0.0, 1.0);
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
      //
      // Thin Bible (India) paper is matte: it diffuses light rather than
      // reflecting a glossy specular streak. A bright pure-white `screen`
      // highlight reads as a glass/plastic sheen, so the highlight is kept low
      // and tuned per theme — `isPaperDark` distinguishes dark vs light paper:
      //   • Light paper: a warm, soft matte sheen, as warm reading light
      //     diffusing across the page.
      //   • Dark paper: a very dim, slightly cool ambient sheen so near-black
      //     stock reads as a real surface gently catching light rather than a
      //     flat void — kept extra low to never look glassy.
      final highlightTone = flapHighlightTone(isPaperDark: isPaperDark);
      final highlightPeak =
          flapHighlightPeakBase(isPaperDark: isPaperDark) * bendStrength;
      final highlightMid =
          flapHighlightMidBase(isPaperDark: isPaperDark) * bendStrength;
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: freeAlign,
            end: foldAlign,
            colors: [
              Colors.transparent,
              highlightTone.withValues(alpha: highlightPeak),
              highlightTone.withValues(alpha: highlightMid),
              Colors.transparent,
            ],
            stops: const [0.0, 0.40, 0.72, 1.0],
          ).createShader(flapRect),
      );
    }

    // Edge / fold masks: hide stray, crushed texture fragments at the flap's
    // free edge and at the fold crease where the mesh compresses.
    //
    // These paint the paper colour over the mesh boundary. On a LIGHT paper
    // that is invisible (paper over paper). On a DARK paper (e.g. pure-black
    // theme) a full-opacity paper-coloured strip wipes the light text in a hard
    // vertical band — the "dark band at the paper edge". Two mitigations:
    //   • keep the masks narrow, and
    //   • on dark paper hold them below full opacity so the text bleeds through
    //     faintly instead of being cut into a solid band.
    // Single-page content is already dimmed by the thin-paper bleed overlay, so
    // the crushed edge fragments are faint and need less aggressive masking.
    final maskPeak = edgeMaskPeakOpacity(isPaperDark: isPaperDark);

    // Edge-fade: mask partial-text artifacts at the flap's free edge.
    final edgeFadeWidth = edgeMaskWidth(isPaperDark: isPaperDark);
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
            paperBackColor.withValues(alpha: maskPeak),
            Colors.transparent,
          ],
        ).createShader(edgeFadeRect),
    );

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    // As the flap narrows near the fold line, texture pixels compress and
    // create visible fragments. This narrow gradient from paperBackColor →
    // transparent softens the fold boundary edge.
    final foldFadeWidth = foldMaskWidth(isPaperDark: isPaperDark);
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
            paperBackColor.withValues(alpha: maskPeak),
            Colors.transparent,
          ],
        ).createShader(foldFadeRect),
    );

    // Fold-edge darkening — drawn LAST so the edge-fade / fold-fade paper masks
    // (which paint bright paper over the crease to hide crushed texture) do not
    // overwrite it. Drawing it before those masks left a bright sliver right at
    // the fold: at an angle that sliver became a diagonal "blade" between the
    // flap's crease shadow and the revealed-page shadow. Keeping it on top makes
    // the crease one continuous dark line at every fold angle.
    if (bendStrength > 0.005 &&
        performanceProfile != DevicePerformanceProfile.low) {
      final foldDarkenAlign =
          g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
      final freeDarkenAlign =
          g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
      // Softer, wider crease darkening: a lower peak spread over a larger
      // falloff reads as gentle paper shading near the fold instead of a hard
      // dark stroke (the "cartoon outline").
      final foldShadow = (isPaperDark ? 0.07 : 0.09) * bendStrength;
      canvas.drawRect(
        flapRect,
        Paint()
          ..blendMode = BlendMode.multiply
          ..shader = LinearGradient(
            begin: foldDarkenAlign,
            end: freeDarkenAlign,
            colors: [
              Colors.black.withValues(alpha: foldShadow),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45],
          ).createShader(flapRect),
      );
    }

    if (needsLayer) canvas.restore();

    canvas.restore();

    // Revealed Page Shadow
    //
    // Soft shadow the lifted flap casts onto the flat page beneath. The shadow
    // band must run parallel to the crease. When the user drags at an angle the
    // fold line tilts (rotateZ around the hinge), so the shadow is drawn inside
    // the SAME fold transform: the local rect's dark edge at foldX maps exactly
    // onto the tilted fold line. Drawing it axis-aligned in screen space instead
    // leaves a bright wedge gap near the fold whenever the angle is non-zero.
    // The screen-space clip below (applied before the transform) still bounds
    // the shadow to the revealed-page side along the curved fold line.
    canvas.save();
    // Clip strictly to the revealed page side along the curved fold line
    final shadowClipPath = isForward
        ? buildOpenPageClipPath(size, g)
        : buildStationaryPageClipPath(size, g);
    canvas.clipPath(shadowClipPath);
    canvas.transform(g.transform.storage);

    final shadowWidth = _kRevealedShadowWidth * g.shadowIntensity;
    final revealedAlpha = 0.11 * g.shadowIntensity;
    if (revealedAlpha > 0.01 && shadowWidth > 1) {
      // The flap's fold boundary is a curved bezier that bulges ~curveOffset/2
      // toward the revealed side at mid-height, so the flap content ends short
      // of the straight foldX line and the revealed page peeks through in a
      // crescent. Extend the shadow past foldX by the bulge and hold it at full
      // strength up to foldX (a dark "plateau"), so the crescent stays shaded
      // instead of showing a bright sliver / diagonal blade. The screen-space
      // curved clip above trims any overshoot back onto the flap.
      final creaseBulge = g.curveOffset.abs();
      final revealedRect = isForward
          ? Rect.fromLTWH(
              g.foldX - creaseBulge,
              0,
              creaseBulge + shadowWidth,
              size.height,
            )
          : Rect.fromLTWH(
              g.foldX - shadowWidth,
              0,
              shadowWidth + creaseBulge,
              size.height,
            );

      // Gradient direction must match the shadow side (darkest at the fold line)
      final beginAlign =
          isForward ? Alignment.centerLeft : Alignment.centerRight;
      final endAlign = isForward ? Alignment.centerRight : Alignment.centerLeft;

      // Fraction of the band occupied by the full-strength plateau (crescent).
      final plateau = revealedRect.width <= 0
          ? 0.0
          : (creaseBulge / revealedRect.width).clamp(0.0, 0.95);

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
              begin: beginAlign,
              end: endAlign,
              colors: [
                // Crescent (flap-side of foldX): a gentle ramp UP to the fold
                // rather than a flat full-strength band, so the crease reads as
                // a soft gradient instead of a thick drawn line — while still
                // staying shaded enough that the bright "blade" never reappears.
                Colors.black.withValues(alpha: revealedAlpha * 0.45),
                Colors.black.withValues(alpha: revealedAlpha),
                Colors.transparent,
              ],
              stops: [0.0, plateau, 1.0],
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
      oldDelegate.singlePageBackContentOpacity != singlePageBackContentOpacity ||
      oldDelegate.performanceProfile != performanceProfile;
}
