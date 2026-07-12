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
    final paperPaint = Paint()
      ..color = paperBackColor.withValues(
        alpha: paperOpacity == 1.0
            ? 1.0
            : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0),
      );
    canvas.drawRect(flapPaintRect, paperPaint);

    final normalizedProgress =
        normalizedFlapProgress(progress, isForward: isActualForward);
    final isSettlePhase = isFlapSettlePhase(
      progress,
      isForward: isActualForward,
      revealStart: flapContentRevealStart,
    );
    final usesLightweightBackFace =
        performanceProfile != DevicePerformanceProfile.high;
    final skipBackFacingMesh =
        !isDoubleSpread && usesLightweightBackFace && !isSettlePhase;

    final hasFlapTexture = flapFrontImage != null && flapFrontSrcRect != null;
    if (hasFlapTexture) {
      final contentReveal = flapFrontContentRevealOpacity(
        progress,
        fadeOutEnd: flapContentFadeOutEnd,
        revealStart: flapContentRevealStart,
        revealEnd: flapContentRevealEnd,
        isForward: isActualForward,
        isDoubleSpread: isDoubleSpread,
        keepSinglePageContentVisible:
            performanceProfile == DevicePerformanceProfile.high,
        doubleSpreadMidFoldBleed: doubleSpreadMidFoldBleed,
      );
      if (contentReveal > 0.001) {
        // Determine which image/rect to use: settle content for Phase 3
        // or mid-fold bleed in high-profile double-spread mode,
        // regular flap content for Phase 1 (early drag).
        final useSettle = isSettlePhase &&
            flapFrontSettleImage != null &&
            flapFrontSettleSrcRect != null;
        final srcImage = useSettle ? flapFrontSettleImage! : flapFrontImage!;
        final srcRect = useSettle ? flapFrontSettleSrcRect! : flapFrontSrcRect!;

        // Minimum width guard: flap narrower than 12 px compresses the full
        // page texture into visible noise. Paper underlay + fade overlay handle
        // this scale — skip the mesh entirely.
        // Mesh rendering is also skipped early in the flip on low/medium devices.
        if (g.flapVisibleWidth >= 12.0 && !skipBackFacingMesh) {
          // Build a triangle mesh that follows the bezier curves so text and
          // images appear to bend with the paper — not a flat board tilting.
          // 16 vertical segments × 6 horizontal columns (4 interior) with
          // surface bulge creates a convex 3D paper curl effect.
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
                  _identityMatrixStorage,
                )
                ..filterQuality = FilterQuality.medium,
            );
          } finally {
            mesh.dispose();
          }

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
          // The default opacity 0.35 reads as thin-paper bleed-through.
          final backDim =
              (!isDoubleSpread && singlePageBackContentOpacity < 1.0)
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
              flapPaintRect,
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
      // Double-spread HIGH pairs a slightly brighter bulge with the deeper
      // cylinder terminator below: roundness is read from the light→dark
      // CONTRAST across the sheet, so lifting the highlight a touch (kept well
      // short of a glassy sheen on matte paper) completes the rounded-tube look.
      // Scoped to double-spread so the separately tuned single-page sheen is
      // unchanged; medium/low keep the flatter, cheaper base sheen.
      final highlightBoost = isDoubleSpread &&
              performanceProfile == DevicePerformanceProfile.high
          ? 1.35
          : 1.0;
      final highlightTone = flapHighlightTone(isPaperDark: isPaperDark);
      final highlightPeak = flapHighlightPeakBase(isPaperDark: isPaperDark) *
          highlightBoost *
          bendStrength;
      final highlightMid = flapHighlightMidBase(isPaperDark: isPaperDark) *
          highlightBoost *
          bendStrength;
      // Curl highlight centred on the bulge: darker at BOTH the free edge and
      // the fold, brightest in the middle — physically how a curved page
      // catches light. Kept away from the fold (transparent by 78%) so it never
      // brightens the crease region; the crease darkening below then reads as
      // one clean valley with no bright sliver ("blade") between the highlight
      // and the crease shadow.
      canvas.drawRect(
        flapPaintRect,
        Paint()
          ..blendMode = BlendMode.screen
          // NOTE: gradient endpoints fade to the SAME hue at alpha 0, never
          // Colors.transparent (transparent BLACK): Flutter lerps RGB toward
          // black as alpha falls, which painted a dark halo mid-ramp — the
          // "two dark pillars" artifact at the flap boundaries on light paper.
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

      // Cylinder curl shading (HIGH profile only): the free-edge half of the
      // flap curls away from the light, so it falls into a soft terminator
      // shadow while the bulge stays lit. Paired with the centre highlight
      // above, the light-bulge-to-dark-edge ramp is what turns a flat-lit flap
      // into a rounded cylinder — the single strongest "this sheet is curved"
      // cue available in 2.5D. Concentrated on the free-edge side and eased to
      // zero before the centre so it never darkens (thickens) the fold crease.
      //
      // The terminator is deliberately stronger than the centre highlight: a
      // curved page reads as rounded from its SHADOW gradient far more than from
      // a matte sheen, and thin Bible paper barely reflects light. The eased
      // 4-stop ramp keeps the free-edge quarter in real shade, then lifts back
      // to the lit bulge by ~62% so there is no hard terminator line.
      if (performanceProfile == DevicePerformanceProfile.high) {
        final cylinderColor = isPaperDark ? Colors.white : Colors.black;
        final cylinderBlend =
            isPaperDark ? BlendMode.screen : BlendMode.multiply;
        // Double-spread deepens the terminator and uses an eased 4-stop ramp so
        // the turning leaf reads as a rounded tube; single-page keeps its
        // separately tuned lighter 3-stop curl so its look is unchanged.
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
          // Fade to transparent PAPER, not Colors.transparent (transparent
          // black), or the ramp's midpoint darkens toward black — this exact
          // mask painted the dark pillar at the free edge on light paper.
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

    // Free-edge highlight: a thin bright line right on the lifted edge, as the
    // rounded paper edge catches ambient light. Together with the contact
    // shadow below it sells the "lifted 3D edge" read instead of a flat cut.
    // Matte and low-alpha (screen) so it never looks glassy; skipped on low.
    if (g.shadowIntensity > 0.02 &&
        performanceProfile != DevicePerformanceProfile.low) {
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
        final highlightAlpha = (isPaperDark ? 0.10 : 0.16) * g.shadowIntensity;
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

    // Fold-edge gradient: mask crushed texture artifacts at the fold crease.
    // As the flap narrows near the fold line, texture pixels compress and
    // create visible fragments. This narrow gradient from paperBackColor →
    // transparent softens the fold boundary edge.
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
          // Transparent PAPER endpoint (see edge-fade note): this mask's
          // black-endpoint ramp painted the dark pillar at the fold line.
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

    // Double-spread fold accent. In single-page mode the unified crease mesh
    // below owns both sides of the fold, so drawing this pass as well would
    // recreate the parallel boundary that makes one sheet look layered.
    if (isDoubleSpread &&
        bendStrength > 0.005 &&
        performanceProfile != DevicePerformanceProfile.low) {
      final foldDarkenAlign =
          g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
      final freeDarkenAlign =
          g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
      final foldDarkenBlend =
          isPaperDark ? BlendMode.screen : BlendMode.multiply;
      final foldDarkenColor = isPaperDark ? Colors.white : Colors.black;
      final foldShadow = (isPaperDark ? 0.02 : 0.05) * bendStrength;
      // Cover the fold-side region where the curl highlight fades out so the
      // crease reads as one soft valley instead of leaving a bright sliver
      // between the highlight and the crease shadow. Low alpha keeps it a gentle
      // shade, not the old wide dark band; the revealed valley below is already
      // narrow+eased so the total crease stays thin.
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

    if (didSaveLayer) canvas.restore();

    canvas.restore();

    // Crease shadow
    //
    // The shadow must share the fold transform and curved centerline. Single
    // pages use one color mesh across the complete crease; double spreads keep
    // the directional revealed-page shadow because they contain separate sheets.
    canvas.save();

    if (!isDoubleSpread) {
      // One sheet, one optical boundary. The old single-page path painted a
      // flap-side darkening, an inner revealed shadow, and an ambient shadow as
      // three independent gradients. Their geometry shared a centreline, but
      // their alpha discontinuities produced parallel vertical borders.
      //
      // The colored mesh below spans both sides of the fold and bends every
      // opacity column with foldCurveXAt, which a straight LinearGradient cannot
      // do. It also replaces three shaded draws with one drawVertices call.
      canvas.clipRect(Offset.zero & size);
      canvas.transform(g.transform.storage);

      final revealedWidth = _kCreaseShadowWidth * 1.8 * g.shadowIntensity;
      final flapWidth = math.min(
        g.flapVisibleWidth,
        math.max(foldFadeWidth, _kCreaseFlapSideWidth) * g.shadowIntensity,
      );
      final peakOpacity =
          (isPaperDark ? 0.07 : 0.13) * g.shadowIntensity * shadowOnset;
      if (peakOpacity > 0.008 && revealedWidth > 1 && flapWidth > 0.5) {
        final density = flapMeshDensityForPerformance(performanceProfile);
        final creaseMesh = buildCurvedCreaseValleyMesh(
          g,
          flapSideWidth: flapWidth,
          revealedSideWidth: revealedWidth,
          color: isPaperDark ? Colors.white : Colors.black,
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
      // Double spreads retain the directional revealed-page shadow because the
      // stationary half and the open half are separate physical sheets.
      final shadowClipPath = isForward
          ? buildOpenPageClipPath(size, g)
          : buildStationaryPageClipPath(size, g);
      canvas.clipPath(shadowClipPath);
      canvas.transform(g.transform.storage);

      // Single unified crease valley: darkest right at the fold, feathering out
      // across the revealed page. Narrower than the layout guard and eased with
      // [_kCreaseValleyStops] so it reads as one soft fold, not a hard stroke.
      final shadowWidth = _kCreaseShadowWidth * g.shadowIntensity;
      final revealedAlpha =
          (isPaperDark ? 0.08 : 0.15) * g.shadowIntensity * shadowOnset;
      if (revealedAlpha > 0.01 && shadowWidth > 1) {
        // Follow the same curved fold boundary as the flap. A straight shadow
        // rect stays angle-aligned after transform, but its dark edge remains a
        // straight line while the paper edge is quadratic, which makes the crease
        // look like two competing layers. The path below shares the fold curve
        // and only bleeds a little across it to cover antialiasing.
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

        final shadowColor = isPaperDark ? Colors.white : Colors.black;

        if (performanceProfile == DevicePerformanceProfile.low) {
          canvas.drawPath(
            shadowPath,
            Paint()
              ..color = shadowColor.withValues(alpha: revealedAlpha * 0.42),
          );
        } else {
          // Inner drop shadow with an eased toe (3-stop) so the crease has no
          // hard edge where it meets the fold line.
          canvas.drawPath(
            shadowPath,
            Paint()
              ..shader = LinearGradient(
                begin: beginAlign,
                end: endAlign,
                colors: [
                  shadowColor.withValues(alpha: revealedAlpha),
                  shadowColor.withValues(alpha: revealedAlpha * 0.45),
                  shadowColor.withValues(alpha: 0),
                ],
                stops: _kCreaseValleyStops,
              ).createShader(shadowBounds),
          );

          // Outer softer ambient band for natural falloff — the wide, low-alpha
          // continuation of the SAME valley (not a second competing band).
          final ambientWidth = shadowWidth * 1.8;
          final ambientPath = buildCurvedFoldShadowPath(
            g,
            isForward: isForward,
            shadowWidth: ambientWidth,
          );
          final ambientAlpha =
              (isPaperDark ? 0.02 : 0.035) * g.shadowIntensity * shadowOnset;
          canvas.drawPath(
            ambientPath,
            Paint()
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

    // Free-edge contact shadow (ambient occlusion): grounds the lifted edge onto
    // the flat page beneath it. Without this the flap reads as a flat sticker
    // with a knife-cut border; a thin soft shadow just OUTSIDE the free edge
    // makes the paper look genuinely lifted. Drawn in its OWN save with the fold
    // transform (so the band stays parallel to the tilted edge) and clipped to
    // the OUTWARD side of the fold — the opposite side from the revealed crease
    // shadow — so it lands on the page beneath the lifted edge, not on the flap.
    if (g.shadowIntensity > 0.02 &&
        performanceProfile != DevicePerformanceProfile.low &&
        g.flapVisibleWidth > 4) {
      // The band widens with the lift so the raised edge throws a longer shadow
      // the higher it rises. Scoped to double-spread (the requested mode): HIGH
      // gets the full soft penumbra (best 2.5D) and the default MEDIUM a modest
      // lift-cast so a two-page turn reads as genuinely lifted, not a flat
      // sticker — at no extra draw cost. Single-page keeps its tuned tight
      // grounding shadow unchanged.
      final isHighContact =
          performanceProfile == DevicePerformanceProfile.high;
      final liftGain = freeEdgeContactLiftGain(
        profile: performanceProfile,
        isDoubleSpread: isDoubleSpread,
      );
      final contactSpread = 1.0 + liftGain * g.shadowIntensity;
      final contactWidth =
          _kFreeEdgeShadowWidth * contactSpread * g.shadowIntensity;
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
          // Outward side = opposite of the revealed-crease clip.
          final contactClip = isForward
              ? buildStationaryPageClipPath(size, g)
              : buildOpenPageClipPath(size, g);
          canvas.clipPath(contactClip);
          canvas.transform(g.transform.storage);

          // Gradient darkest at the edge, fading outward across the page with an
          // eased 3-stop penumbra (soft shoulder) instead of a linear ramp, so
          // the cast shadow has a believable soft edge rather than a hard band.
          final begin =
              g.flapRightOfFold ? Alignment.centerLeft : Alignment.centerRight;
          final end =
              g.flapRightOfFold ? Alignment.centerRight : Alignment.centerLeft;
          final contactColor = isPaperDark ? Colors.white : Colors.black;
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

    // Stationary Page Shadow (double-spread only; single-page stationary layer is
    // left of the fold and must not receive transformed shadows from the flip side).
    //
    // Clip along the curved fold boundary (perpendicular bleed via foldNormal),
    // not an axis-aligned rect — otherwise extreme vertical drags leave the shadow
    // band misaligned with the tilted crease on the stationary half.
    if (isRightToLeft && isDoubleSpread) {
      canvas.save();
      final stationaryShadowClip = isForward
          ? buildStationaryPageClipPath(size, g)
          : buildOpenPageClipPath(size, g);
      canvas.clipPath(stationaryShadowClip);
      canvas.transform(g.transform.storage);

      final stationaryWidth = _kStationaryShadowWidth * g.shadowIntensity;
      final stationaryAlpha = 0.06 * g.shadowIntensity * shadowOnset;
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

        final shadowColor = isPaperDark ? Colors.white : Colors.black;
        final shadowBlend =
            isPaperDark ? BlendMode.srcOver : BlendMode.multiply;

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

    // Center binding gutter (double-spread): a symmetric valley centred on the
    // spine, darkest at the binding and feathering out to BOTH sides.
    //
    // The previous groove painted a single one-sided band clipped hard to the
    // flip half, so its full-alpha edge sat exactly on the spine while the
    // stationary half stayed at zero. That step read as a knife-cut running
    // straight down the middle of the spread — the "shadow sharply clipped at
    // the body text" artifact. A real binding gutter darkens both facing pages,
    // so the two feathered sides below share the same peak alpha at the spine
    // and are therefore continuous across it (no centre seam). The lifting side
    // reaches a little further (its page is pulling the gutter open) while the
    // resting side stays narrow so the stationary page's text is barely grazed.
    if (isDoubleSpread && progress > 0) {
      final shadowColor = isPaperDark ? Colors.white : Colors.black;
      final shadowBlend = isPaperDark ? BlendMode.srcOver : BlendMode.multiply;
      final isLowProfileGutter =
          performanceProfile == DevicePerformanceProfile.low;
      // Shared peak at the spine (onset-eased so it fades in with the turn
      // instead of snapping on in the middle of the spread).
      final gutterPeak =
          (isPaperDark ? 0.09 : 0.12) * g.shadowIntensity * shadowOnset;

      const flipSideWidth = 18.0;
      const stationarySideWidth = 13.0;

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
          // Peak sits on the spine edge; transparent at the outer edge.
          final peakAtLeft = outward > 0; // spine is the rect's left edge
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

      // Flip side (page lifting away from the spine) reaches further; the
      // stationary side is narrower. Directions mirror for backward turns.
      drawGutterSide(g.isForward ? flipSideWidth : -flipSideWidth);
      drawGutterSide(g.isForward ? -stationarySideWidth : stationarySideWidth);
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
      oldDelegate.performanceProfile != performanceProfile;
}
