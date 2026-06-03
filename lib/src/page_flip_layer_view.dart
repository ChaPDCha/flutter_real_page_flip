import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

// LAYOUT GATE: constrainedSize + _wrapWithConstraints for Offstage/current/flip pages.
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

/// Renders the page layers (Bottom, Middle, Flap) based on the current drag state.
class PageFlipLayerView extends StatelessWidget {
  /// Creates a [PageFlipLayerView].
  const PageFlipLayerView({
    /// Total number of pages.
    required this.itemCount, /// Currently visible page index.
    required this.currentIndex, /// Normalised drag progress (0.0 to 1.0).
    required this.dragProgress, /// Whether a drag gesture is active.
    required this.isDragging, /// Whether the drag direction is forward.
    required this.isForward, /// Current touch position in local coordinates.
    required this.touchPosition,     /// Cached snapshots of pre-rendered pages.
    required this.pageSnapshots, /// Spread snapshots for flap front texture.
    required this.spreadSnapshots, /// GlobalKeys for tracking rendered pages.
    required this.pageKeys, /// Builder for page widgets.
    this.itemBuilder,

    /// Color of the paper flap back side.
    this.paperFlapColor,

    /// Opacity of the paper flap back side.
    this.paperOpacity = 1.0,

    /// Optional explicit size to constrain children.
    this.constrainedSize,

    /// True if rendering for a dual spread book
    this.isDoubleSpread = false,
    super.key,
  });

  /// Builder for page widgets.
  final IndexedWidgetBuilder? itemBuilder;

  /// Total number of pages.
  final int itemCount;

  /// Currently visible page index.
  final int currentIndex;

  /// Normalised drag progress (0.0 to 1.0).
  final double dragProgress;

  /// Whether a drag gesture is active.
  final bool isDragging;

  /// Whether the drag direction is forward.
  final bool isForward;

  /// Current touch position in local coordinates.
  final Offset touchPosition;

  /// Cached snapshots of pre-rendered pages.
  final Map<int, ui.Image> pageSnapshots;

  /// Spread snapshots for flap front texture mapping.
  final Map<int, ui.Image> spreadSnapshots;

  /// GlobalKeys for tracking rendered pages.
  final Map<int, GlobalKey> pageKeys;

  /// Color of the paper flap back side.
  final Color? paperFlapColor;

  /// Opacity of the paper flap back side.
  final double paperOpacity;

  /// Optional explicit size to constrain children (prevents infinite height from Stack).
  final Size? constrainedSize;

  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// Wraps a widget with SizedBox if constrainedSize is provided.
  /// Prevents infinite height propagation from Stack(fit: StackFit.expand).
  Widget _wrapWithConstraints(Widget child) {
    if (constrainedSize == null) return child;
    return SizedBox(
      width: constrainedSize!.width,
      height: constrainedSize!.height,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    final currentKey = pageKeys[currentIndex] ?? GlobalKey();
    final keyedCurrentPage = _wrapWithConstraints(
      RepaintBoundary(
        key: currentKey,
        child: _buildPage(context, currentIndex),
      ),
    );

    // Background pre-renders: Only build CURRENT window (prev, next)
    // to avoid layout overhead of 1000s of Offstage pages.
    // IMPORTANT: These are ALWAYS kept in the tree (even during drag/animation)
    // so that _buildPageContent can fall back to a live widget that is already
    // laid out, preventing blank-frame flashes when snapshots are unavailable.
    final backgroundWidgets = <Widget>[];

    // Windowing: Only keep -1 and +1 in the tree
    final windowIndices = {
      if (currentIndex > 0) currentIndex - 1,
      if (currentIndex < itemCount - 1) currentIndex + 1,
    };

    // Skip indices already painted in visible flip layers to avoid duplicate
    // compositing (e.g. next page in bottom layer during forward drag).
    final visibleDuringFlip = <int>{};
    if (dragProgress > 0 && isDragging) {
      if (isForward) {
        if (currentIndex < itemCount - 1) {
          visibleDuringFlip.add(currentIndex + 1);
        }
      } else if (currentIndex > 0) {
        visibleDuringFlip.add(currentIndex - 1);
      }
    }

    for (final index in windowIndices) {
      if (visibleDuringFlip.contains(index)) continue;

      final key = pageKeys[index];
      if (key == null) continue;

      backgroundWidgets.add(
        Offstage(
          offstage: true,
          child: _wrapWithConstraints(
            RepaintBoundary(key: key, child: _buildPage(context, index)),
          ),
        ),
      );
    }

    // Forward flip: keep a keyed Offstage copy for snapshot capture while the
    // visible middle layer uses [_buildPageContent] (opaque snapshot), matching
    // backward flip where the middle layer never hosts the GlobalKey.
    if (dragProgress > 0 &&
        isDragging &&
        isForward &&
        !visibleDuringFlip.contains(currentIndex)) {
      final currentKey = pageKeys[currentIndex];
      if (currentKey != null) {
        backgroundWidgets.add(
          Offstage(
            child: _wrapWithConstraints(
              RepaintBoundary(
                key: currentKey,
                child: _buildPage(context, currentIndex),
              ),
            ),
          ),
        );
      }
    }

    if (dragProgress <= 0 || !isDragging) {
      return Stack(
        fit: StackFit.expand,
        children: [...backgroundWidgets, keyedCurrentPage],
      );
    }

    final floatProgress = isForward ? dragProgress : 1.0 - dragProgress;

    Widget? nextPageContent;
    if (currentIndex < itemCount - 1) {
      nextPageContent = _buildPageContent(context, currentIndex + 1);
    }

    Widget? previousPageContent;
    if (currentIndex > 0) {
      previousPageContent = _buildPageContent(context, currentIndex - 1);
    }

    final Widget bottomLayerContent;
    final Widget middleLayerContent;

    if (isForward) {
      // Double-spread: bottom keeps the current spread under the right fold;
      // next spread left page appears only via [_buildSpineRevealBand] on the left.
      // Single-page: bottom reveals the next page behind the fold.
      bottomLayerContent = isDoubleSpread
          ? _buildPageContent(context, currentIndex)
          : (nextPageContent ?? _buildOpaquePaperUnderlay(context));
      // Double-spread: stationary left half of current spread in layer 2.
      // Single-page: opaque paper underlay (left of fold) — flap texture in
      // layer 3 shows the turning page; do not duplicate page content here.
      middleLayerContent = isDoubleSpread
          ? _buildPageContent(context, currentIndex)
          : _buildOpaquePaperUnderlay(context);
    } else {
      middleLayerContent =
          previousPageContent ?? _buildOpaquePaperUnderlay(context);
      bottomLayerContent = keyedCurrentPage;
    }

    final flapSpreadIndex = _flapSpreadSnapshotIndex();
    final flapFrontImage = flapSpreadIndex != null
        ? spreadSnapshots[flapSpreadIndex]
        : null;
    final canvasSize = constrainedSize ?? Size.zero;
    final flapFrontSrcRect = flapFrontImage != null
        ? flapFrontSourceRect(
            imageSize: Size(
              flapFrontImage.width.toDouble(),
              flapFrontImage.height.toDouble(),
            ),
            isDoubleSpread: isDoubleSpread,
            isForward: isForward,
          )
        : null;
    final resolvedFlapDestRect =
        flapFrontSrcRect != null && canvasSize.width > 0 && canvasSize.height > 0
            ? flapFrontDestRect(
                size: canvasSize,
                isDoubleSpread: isDoubleSpread,
                isForward: isForward,
              )
            : null;

    final geo = PageFlipGeometry(
      progress: floatProgress,
      isRightToLeft: true,
      touchOffset: touchPosition,
      size: canvasSize,
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        ...backgroundWidgets,
        // Layer 1: Bottom (revealed page behind the fold)
        ClipPath(
          clipper: PageFlipOpenClipper(
            progress: floatProgress,
            isRightToLeft: true,
            touchOffset: touchPosition,
            isDoubleSpread: isDoubleSpread,
            isForward: isForward,
          ),
          child: bottomLayerContent,
        ),
        // Layer 2: Middle (stationary spread half + spine reveal band + clip)
        ClipPath(
          clipper: PageFlipClipper(
            progress: floatProgress,
            isRightToLeft: true,
            touchOffset: touchPosition,
            isDoubleSpread: isDoubleSpread,
            isForward: isForward,
          ),
          child: _buildMiddleLayerStack(context, geo, middleLayerContent),
        ),
        // Layer 3: Flap shadow & highlight effects
        IgnorePointer(
          child: CustomPaint(
            size: constrainedSize ?? Size.infinite,
            painter: PageFlipPainter(
              progress: floatProgress,
              isRightToLeft: true,
              touchOffset: touchPosition,
              paperBackColor:
                  paperFlapColor ?? Theme.of(context).scaffoldBackgroundColor,
              isDoubleSpread: isDoubleSpread,
              isForward: isForward,
              paperOpacity: paperOpacity,
              flapFrontImage: flapFrontImage,
              flapFrontSrcRect: flapFrontSrcRect,
              flapFrontDestRect: resolvedFlapDestRect,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) => itemBuilder!(context, index);

  /// Composes middle-layer children for double spread vs single page.
  Widget _buildMiddleLayerStack(
    BuildContext context,
    PageFlipGeometry geo,
    Widget middleLayerContent,
  ) {
    if (!isDoubleSpread) {
      return middleLayerContent;
    }

    final spineReveal = _buildSpineRevealBand(context, geo);
    final stationaryHalf = _buildStationarySpreadHalf(middleLayerContent);

    if (spineReveal == null) {
      return stationaryHalf;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        stationaryHalf,
        spineReveal,
      ],
    );
  }

  /// Stationary half of the middle spread (left on forward, right on backward).
  Widget _buildStationarySpreadHalf(Widget spreadContent) {
    return clipSpreadPageHalf(
      alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
      child: spreadContent,
    );
  }

  /// Spine-band reveal of the adjacent spread page, or null when unavailable.
  Widget? _buildSpineRevealBand(BuildContext context, PageFlipGeometry geo) {
    if (buildDoubleSpreadSpineRevealPath(geo) == null) {
      return null;
    }

    if (isForward) {
      if (currentIndex >= itemCount - 1) return null;
      return ClipPath(
        clipper: PageFlipSpineRevealClipper(geo: geo),
        child: _buildSpreadHalfContent(
          context,
          spreadIndex: currentIndex + 1,
          alignment: Alignment.centerLeft,
        ),
      );
    }

    if (currentIndex <= 0) return null;
    return ClipPath(
      clipper: PageFlipSpineRevealClipper(geo: geo),
      child: _buildSpreadHalfContent(
        context,
        spreadIndex: currentIndex - 1,
        alignment: Alignment.centerRight,
      ),
    );
  }

  /// One half of a spread snapshot or live spread widget.
  Widget _buildSpreadHalfContent(
    BuildContext context, {
    required int spreadIndex,
    required Alignment alignment,
  }) {
    final spreadImage = spreadSnapshots[spreadIndex];
    if (spreadImage != null) {
      return clipSpreadPageHalf(
        alignment: alignment,
        child: RawImage(image: spreadImage, fit: BoxFit.fill),
      );
    }

    // Fallback: live spread from itemBuilder (must be full double-spread layout).
    return clipSpreadPageHalf(
      alignment: alignment,
      child: _buildPageContent(context, spreadIndex),
    );
  }

  /// Opaque paper underlay for the stationary strip (matches [PageFlipPainter] paper back).
  Widget _buildOpaquePaperUnderlay(BuildContext context) {
    final paperColor =
        paperFlapColor ?? Theme.of(context).scaffoldBackgroundColor;
    final luminance = paperColor.computeLuminance();
    final isPaperDark = luminance < 0.20;
    final alpha = paperOpacity == 1.0
        ? 1.0
        : (isPaperDark ? paperOpacity * 1.1 : paperOpacity).clamp(0.0, 1.0);
    return ColoredBox(color: paperColor.withValues(alpha: alpha));
  }

  /// Spread snapshot index used for flap front texture, or null if unavailable.
  int? _flapSpreadSnapshotIndex() {
    if (isDoubleSpread) {
      if (isForward) {
        if (currentIndex < itemCount - 1) return currentIndex + 1;
        return null;
      } else {
        if (currentIndex > 0) return currentIndex - 1;
        return null;
      }
    }
    // Single page mode:
    if (isForward) return currentIndex;
    return null;
  }

  /// Builds the content widget for a target page during an active flip.
  ///
  /// Priority order:
  /// 1. Pre-captured snapshot (RawImage) — fastest, pixel-perfect.
  /// 2. Fresh widget build — always shows real content since the Offstage
  ///    widgets are kept alive in the tree for snapshot capture.
  ///
  /// NOTE: We intentionally do NOT reuse GlobalKeys here to avoid
  /// "Multiple widgets used the same GlobalKey" errors. The Offstage
  /// widgets already use the GlobalKeys for snapshot capture.
  Widget _buildPageContent(BuildContext context, int index) {
    // 1st priority: pre-captured page snapshot
    final snapshot = pageSnapshots[index];
    if (snapshot != null) {
      return RawImage(image: snapshot, fit: BoxFit.fill);
    }

    // 2nd priority: fresh build (live content, no GlobalKey conflict)
    return _wrapWithConstraints(
      RepaintBoundary(child: _buildPage(context, index)),
    );
  }
}
