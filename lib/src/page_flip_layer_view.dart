import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/flip_layer_policy.dart';

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

    /// Progress by which flap-front content is fully hidden during fold.
    this.flapContentFadeOutEnd = 0.20,

    /// Progress before late settle content fades in.
    this.flapContentRevealStart = 0.85,

    /// Progress at which flap-front content is fully visible.
    this.flapContentRevealEnd = 0.95,

    /// Optional explicit size to constrain children.
    this.constrainedSize,

    /// True if rendering for a dual spread book
    this.isDoubleSpread = false,

    /// One-frame bridge after a successful flip: show cached snapshot while
    /// the live [currentIndex] page paints in [Offstage] (avoids settle flicker).
    this.settleBridgeActive = false,
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

  /// Progress by which flap-front content is fully hidden during fold.
  final double flapContentFadeOutEnd;

  /// Progress before late settle content fades in.
  final double flapContentRevealStart;

  /// Progress at which flap-front content is fully visible.
  final double flapContentRevealEnd;

  /// Optional explicit size to constrain children (prevents infinite height from Stack).
  final Size? constrainedSize;

  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// One-frame snapshot bridge after page index changes (see [settleBridgeActive]).
  final bool settleBridgeActive;

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
    // so PreRenderManager can capture snapshots from keyed Offstage RepaintBoundaries.
    final backgroundWidgets = <Widget>[];

    // Windowing: Only keep -1 and +1 in the tree
    final windowIndices = {
      if (currentIndex > 0) currentIndex - 1,
      if (currentIndex < itemCount - 1) currentIndex + 1,
    };

    for (final index in windowIndices) {
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

    // During drag keep current page's keyed Offstage in tree so PreRenderManager
    // can capture snapshots (the visible flip layers use snapshot images, not
    // live GlobalKey widgets, so the Offstage is the only live copy in the tree).
    if (dragProgress > 0 && isDragging) {
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
      final bridgeLayer = settleBridgeActive
          ? _buildSettleBridgeSnapshotLayer(context)
          : null;
      if (bridgeLayer != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...backgroundWidgets,
            bridgeLayer,
            Offstage(offstage: true, child: keyedCurrentPage),
          ],
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [...backgroundWidgets, keyedCurrentPage],
      );
    }

    final floatProgress = isForward ? dragProgress : 1.0 - dragProgress;

    final policy = FlipLayerPolicy(
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
      currentIndex: currentIndex,
      itemCount: itemCount,
    );

    // Bottom layer: content revealed behind the fold
    final Widget bottomLayerContent;
    final bottomHalf = policy.bottomSpreadHalf;
    if (bottomHalf != null) {
      bottomLayerContent = _buildSpreadHalfContent(
        context,
        spreadIndex: bottomHalf.index,
        alignment: bottomHalf.alignment,
      );
    } else if (policy.bottomPageIndex case final int index?) {
      bottomLayerContent = _buildPageContent(context, index);
    } else {
      bottomLayerContent = _buildOpaquePaperUnderlay(context);
    }

    // Middle layer: stationary content under the flap
    final Widget middleLayerContent;
    if (policy.middleSpreadIndex case final int index?) {
      middleLayerContent = _buildPageContent(context, index);
    } else if (policy.middlePageIndex case final int index?) {
      middleLayerContent = _buildPageContent(context, index);
    } else {
      middleLayerContent = _buildOpaquePaperUnderlay(context);
    }

    final flapSpreadIndex = policy.flapSnapshotSpreadIndex;
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
            geo: geo,
          ),
          child: bottomLayerContent,
        ),
        // Layer 2: Middle (stationary spread half + spine reveal band + clip)
        // Backward double-spread: stationary RIGHT half must stay right-of-fold
        // (PageFlipOpenClipper inside [_buildMiddleLayerStack]). Wrapping the whole
        // stack in PageFlipClipper (left-of-fold) exposed the bottom layer's previous
        // spread on the right where the current right page should remain fixed.
        _buildMiddleLayer(context, geo, middleLayerContent, floatProgress, policy),
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
              flapContentFadeOutEnd: flapContentFadeOutEnd,
              flapContentRevealStart: flapContentRevealStart,
              flapContentRevealEnd: flapContentRevealEnd,
              flapFrontImage: flapFrontImage,
              flapFrontSrcRect: flapFrontSrcRect,
              flapFrontDestRect: resolvedFlapDestRect,
              geo: geo,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) => itemBuilder!(context, index);

  /// Full-viewport snapshot of [currentIndex] for the post-flip settle bridge.
  Widget? _buildSettleBridgeSnapshotLayer(BuildContext context) {
    if (isDoubleSpread) {
      final spreadImage = spreadSnapshots[currentIndex];
      if (spreadImage != null) {
        return _wrapWithConstraints(
          RepaintBoundary(child: _buildSnapshotImage(spreadImage)),
        );
      }
    }

    final pageImage = pageSnapshots[currentIndex];
    if (pageImage == null) return null;

    return _wrapWithConstraints(
      RepaintBoundary(child: _buildSnapshotImage(pageImage)),
    );
  }

  /// Layer 2 wrapper: applies fold clip for forward/single; backward double-spread
  /// clips stationary right and spine reveal separately inside the stack.
  Widget _buildMiddleLayer(
    BuildContext context,
    PageFlipGeometry geo,
    Widget middleLayerContent,
    double floatProgress,
    FlipLayerPolicy policy,
  ) {
    final stack = _buildMiddleLayerStack(context, geo, middleLayerContent, policy);

    if (isDoubleSpread && !isForward) {
      return stack;
    }

    return ClipPath(
      clipper: PageFlipClipper(
        progress: floatProgress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
        geo: geo,
      ),
      child: stack,
    );
  }

  /// Composes middle-layer children for double spread vs single page.
  Widget _buildMiddleLayerStack(
    BuildContext context,
    PageFlipGeometry geo,
    Widget middleLayerContent,
    FlipLayerPolicy policy,
  ) {
    if (!isDoubleSpread) {
      return middleLayerContent;
    }

    final spineReveal = _buildSpineRevealBand(context, geo, policy);
    final stationaryHalf = _buildStationarySpreadHalf(middleLayerContent);

    if (!isForward) {
      final stationaryClipper = PageFlipOpenClipper(
        progress: geo.progress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: true,
        isForward: false,
        geo: geo,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (spineReveal != null) spineReveal,
          ClipPath(
            clipper: stationaryClipper,
            child: stationaryHalf,
          ),
        ],
      );
    }

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
    return clipFullSpreadHalf(
      alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
      child: spreadContent,
    );
  }

  /// Spine-band reveal of the adjacent spread page, or null when unavailable.
  Widget? _buildSpineRevealBand(
    BuildContext context,
    PageFlipGeometry geo,
    FlipLayerPolicy policy,
  ) {
    if (buildDoubleSpreadSpineRevealPath(geo) == null) return null;
    final spreadIndex = policy.spineRevealSpreadIndex;
    if (spreadIndex == null) return null;
    return ClipPath(
      clipper: PageFlipSpineRevealClipper(geo: geo),
      child: _buildSpreadHalfContent(
        context,
        spreadIndex: spreadIndex,
        alignment: Alignment.centerLeft,
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
      return clipFullSpreadHalf(
        alignment: alignment,
        child: _buildSnapshotImage(spreadImage),
      );
    }

    // During flip, never fall back to live widgets — paper underlay until snapshot arrives.
    return clipFullSpreadHalf(
      alignment: alignment,
      child: _buildOpaquePaperUnderlay(context),
    );
  }

  /// Renders a captured snapshot at [constrainedSize] (logical viewport).
  Widget _buildSnapshotImage(ui.Image image) {
    final viewport = constrainedSize ?? Size.zero;
    final snapshot = buildViewportSnapshotImage(
      image,
      viewportSize: viewport,
    );
    return viewport.width > 0 && viewport.height > 0
        ? snapshot
        : _wrapWithConstraints(snapshot);
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

  /// Builds the content widget for a target page during an active flip.
  ///
  /// Uses pre-captured snapshots only. Live [itemBuilder] widgets are never
  /// shown in flip layers — Offstage copies hold GlobalKeys for capture.
  /// When a snapshot is not ready yet, an opaque paper underlay is shown.
  Widget _buildPageContent(BuildContext context, int index) {
    // Double-spread: full spread snapshots (current index is spread-only in PreRenderManager).
    if (isDoubleSpread) {
      final spreadImage = spreadSnapshots[index];
      if (spreadImage != null) {
        return _wrapWithConstraints(
          RepaintBoundary(child: _buildSnapshotImage(spreadImage)),
        );
      }
    }

    // Single-page (or spread fallback): per-page snapshot
    final snapshot = pageSnapshots[index];
    if (snapshot != null) {
      return _wrapWithConstraints(
        RepaintBoundary(child: _buildSnapshotImage(snapshot)),
      );
    }

    return _buildOpaquePaperUnderlay(context);
  }
}
