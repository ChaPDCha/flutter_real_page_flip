import 'dart:ui';

/// Returns the source rect within a spread snapshot for the flipping flap front.
///
/// Double-spread maps the physically exposed verso strip from the adjacent
/// spread. Forward uses a left-anchored strip from the next spread's left page;
/// backward uses a right-anchored strip from the previous spread's right page.
/// Single-page (both directions): full page rect — the current page wraps onto
/// the flap so content is visible during the turn.
Rect? flapFrontSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
  double? floatProgress,
}) {
  if (isDoubleSpread) {
    final halfWidth = imageSize.width / 2;
    final p = (floatProgress ?? (isForward ? 1.0 : 0.0)).clamp(0.0, 1.0);
    final materialFraction = isForward ? p : 1.0 - p;
    final stripWidth = halfWidth * materialFraction;
    if (isForward) {
      return Rect.fromLTWH(0, 0, stripWidth, imageSize.height);
    }
    return Rect.fromLTWH(
      imageSize.width - stripWidth,
      0,
      stripWidth,
      imageSize.height,
    );
  }

  // Single-page: when [floatProgress] is supplied, map only the LIFTED strip
  // (the page's right portion of width floatProgress·pageWidth) onto the flap.
  // This keeps the crease continuous with the page beneath and preserves the
  // text's horizontal scale, instead of crushing the whole page into the
  // narrowing flap (the "over-compressed back side" artifact). The mesh is
  // drawn with flipHorizontal so this right-anchored strip reads correctly as
  // the folded-over paper.
  if (floatProgress != null) {
    return singlePagePeeledStripRect(imageSize, floatProgress);
  }

  return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
}

/// Right-anchored source strip for the single-page flap at [floatProgress].
///
/// Width grows with the lifted material: `floatProgress · width`, anchored at
/// the page's right edge so the crease (fold) edge stays continuous with the
/// stationary page and the free edge reveals the page's right border.
Rect singlePagePeeledStripRect(Size imageSize, double floatProgress) {
  final p = floatProgress.clamp(0.0, 1.0);
  final stripWidth = imageSize.width * p;
  return Rect.fromLTWH(
    imageSize.width - stripWidth,
    0,
    stripWidth,
    imageSize.height,
  );
}

/// Legacy back-content helper. The double-spread flap front now directly maps
/// the real verso strip, so a second mirrored ghost texture is never needed.
Rect? flapBackSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
}) =>
    null;

/// Returns the source rect within a spread snapshot for settle-phase flap front content.
///
/// During the settle phase (progress 0.85-0.95), the flap shows the **destination**
/// page instead of the page being peeled:
/// - Forward double-spread: LEFT half of the NEXT spread (the page appearing
///   on the right side of the viewport).
/// - Backward double-spread: RIGHT half of the PREVIOUS spread (the page appearing
///   on the left side of the viewport).
/// - Single-page (both directions): unchanged full-page source rect.
Rect? flapFrontSettleSourceRect({
  required Size imageSize,
  required bool isDoubleSpread,
  required bool isForward,
  double? floatProgress,
}) {
  if (isDoubleSpread) {
    return flapFrontSourceRect(
      imageSize: imageSize,
      isDoubleSpread: true,
      isForward: isForward,
      floatProgress: floatProgress,
    );
  }

  // Single-page settle phase reuses the same peeled-strip mapping as the front
  // so the page does not "snap" scale between the peel and settle phases.
  if (floatProgress != null) {
    return singlePagePeeledStripRect(imageSize, floatProgress);
  }

  return Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
}
