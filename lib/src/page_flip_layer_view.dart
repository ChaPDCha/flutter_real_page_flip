import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/flip_layer_policy.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

// LAYOUT GATE: constrainedSize + _wrapWithConstraints for Offstage/current/flip pages.
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

/// Renders the page layers (Bottom, Middle, Flap) based on the current drag state.
class PageFlipLayerView extends StatelessWidget {
  /// Creates a [PageFlipLayerView].
  const PageFlipLayerView({
    /// Total number of pages.
    required this.itemCount,

    /// Currently visible page index.
    required this.currentIndex,

    /// Normalised drag progress (0.0 to 1.0).
    required this.dragProgress,

    /// Whether a drag gesture is active.
    required this.isDragging,

    /// Whether the drag direction is forward.
    required this.isForward,

    /// Current touch position in local coordinates.
    required this.touchPosition,

    /// Cached snapshots of pre-rendered pages.
    required this.pageSnapshots,

    /// Spread snapshots for flap front texture.
    required this.spreadSnapshots,

    /// GlobalKeys for tracking rendered pages.
    required this.pageKeys,

    /// Builder for page widgets.
    this.itemBuilder,

    /// Color of the paper flap back side.
    this.paperFlapColor,

    /// Opacity of the paper flap back side.
    this.paperOpacity = 1.0,

    /// How much the paper appears translucent at mid-flip (0.0–1.0).
    this.thinPaperStrength = 0.0,

    /// How much the next page content shows through at end of flip (0.0–1.0).
    this.endRevealStrength = 0.0,

    /// Progress by which flap-front content is fully hidden during fold.
    this.flapContentFadeOutEnd = 0.20,

    /// Progress before late settle content fades in.
    this.flapContentRevealStart = 0.85,

    /// Progress at which flap-front content is fully visible.
    this.flapContentRevealEnd = 0.95,

    /// How visible the 2.5D page back content is (0.0–1.0, double-spread only).
    this.flapBackStrength = 0.0,

    /// Optional explicit size to constrain children.
    this.constrainedSize,

    /// True if rendering for a dual spread book
    this.isDoubleSpread = false,

    /// Performance profile to control rendering quality.
    this.performanceProfile = DevicePerformanceProfile.high,

    /// Animation controller for driving fade transitions.
    this.flipAnimation,
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

  /// How much the paper appears translucent at mid-flip (0.0–1.0).
  final double thinPaperStrength;

  /// How much the next page content shows through at end of flip (0.0–1.0).
  final double endRevealStrength;

  /// Progress by which flap-front content is fully hidden during fold.
  final double flapContentFadeOutEnd;

  /// Progress before late settle content fades in.
  final double flapContentRevealStart;

  /// Progress at which flap-front content is fully visible.
  final double flapContentRevealEnd;

  /// How visible the 2.5D page back content is (0.0–1.0, double-spread only).
  final double flapBackStrength;

  /// Optional explicit size to constrain children (prevents infinite height from Stack).
  final Size? constrainedSize;

  /// True if rendering for a dual spread book
  final bool isDoubleSpread;

  /// Performance profile to control rendering quality.
  final DevicePerformanceProfile performanceProfile;

  /// Animation controller from parent for driving fade transitions.
  /// Used by [FadeTransition] instead of [Opacity] for better compositing.
  final Animation<double>? flipAnimation;

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

    final isDragActive = dragProgress > 0 && isDragging;

    // Current page: always present at this Stack position.
    final currentKey = pageKeys[currentIndex];
    final currentPage = OffscreenPreRenderer(
      isOffscreen: isDragActive,
      child: RepaintBoundary(
        key: currentKey,
        child: _wrapWithConstraints(_buildPage(context, currentIndex)),
      ),
    );

    // Background adjacent pages kept in the tree for snapshot capture.
    final backgroundWidgets = <Widget>[];
    final windowIndices = {
      if (currentIndex > 0) currentIndex - 1,
      if (currentIndex < itemCount - 1) currentIndex + 1,
    };

    for (final index in windowIndices) {
      final gKey = pageKeys[index];
      if (gKey == null) continue;

      backgroundWidgets.add(
        OffscreenPreRenderer(
          isOffscreen: true,
          child: RepaintBoundary(
            key: gKey,
            child: _wrapWithConstraints(_buildPage(context, index)),
          ),
        ),
      );
    }

    if (isDragActive) {
      return _buildDragLayout(context, currentPage, backgroundWidgets);
    }

    // Non-drag: current page visible, adjacent pages offstage.
    return Stack(
      fit: StackFit.expand,
      children: [...backgroundWidgets, currentPage],
    );
  }

  /// Builds the drag-mode layout with flip layers on top of [currentPage].
  Widget _buildDragLayout(
    BuildContext context,
    Widget currentPage,
    List<Widget> backgroundWidgets,
  ) {
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
    if (policy.middleSpreadHalf case final half?) {
      middleLayerContent = _buildPageContent(context, half.index);
    } else if (policy.middlePageIndex case final int index?) {
      middleLayerContent = _buildPageContent(context, index);
    } else {
      middleLayerContent = _buildOpaquePaperUnderlay(context);
    }

    final flapSpreadIndex = policy.flapSnapshotSpreadIndex;
    final flapFrontImage =
        flapSpreadIndex != null ? spreadSnapshots[flapSpreadIndex] : null;
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
    final resolvedFlapDestRect = flapFrontSrcRect != null &&
            canvasSize.width > 0 &&
            canvasSize.height > 0
        ? flapFrontDestRect(
            size: canvasSize,
            isDoubleSpread: isDoubleSpread,
            isForward: isForward,
          )
        : null;

    // Settle-phase flap content: shows the DESTINATION page instead of the
    // peeled page during Phase 3 (progress 0.85-0.95).
    final flapSettleSpreadIndex = policy.flapSettleSnapshotSpreadIndex;
    final flapFrontSettleImage = flapSettleSpreadIndex != null
        ? spreadSnapshots[flapSettleSpreadIndex]
        : null;
    final flapFrontSettleSrcRect = flapFrontSettleImage != null
        ? flapFrontSettleSourceRect(
            imageSize: Size(
              flapFrontSettleImage.width.toDouble(),
              flapFrontSettleImage.height.toDouble(),
            ),
            isDoubleSpread: isDoubleSpread,
            isForward: isForward,
          )
        : null;

    // 2.5D page back content: same half geometry as front, from adjacent spread.
    final flapBackSpreadIndex = policy.flapBackSnapshotSpreadIndex;
    final flapBackImage = flapBackSpreadIndex != null
        ? spreadSnapshots[flapBackSpreadIndex]
        : null;
    final flapBackSrcRect = flapBackImage != null
        ? flapBackSourceRect(
            imageSize: Size(
              flapBackImage.width.toDouble(),
              flapBackImage.height.toDouble(),
            ),
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

    final CustomClipper<Path> bottomClipper;
    if (isDoubleSpread && !isForward) {
      bottomClipper = PageFlipClipper(
        progress: floatProgress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
        geo: geo,
      );
    } else {
      bottomClipper = PageFlipOpenClipper(
        progress: floatProgress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
        geo: geo,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ...backgroundWidgets,
        currentPage,
        // Layer 1: Bottom (revealed page behind the fold)
        ClipPath(
          clipper: bottomClipper,
          child: (() {
            var child = bottomLayerContent;
            // Apply fade-in to the destination page on the bottom layer.
            // Single backward mode uses the bottom layer for the CURRENT page (origin), not destination.
            if (isDoubleSpread || isForward) {
              var opacity = 1.0;
              if (floatProgress < flapContentRevealStart) {
                opacity = 0.0;
              } else if (floatProgress >= flapContentRevealEnd) {
                opacity = 1.0;
              } else {
                final divisor = flapContentRevealEnd - flapContentRevealStart;
                if (divisor > 0.001) {
                  final t = (floatProgress - flapContentRevealStart) / divisor;
                  opacity = t * t * (3 - 2 * t);
                } else {
                  opacity = 1.0;
                }
              }
              // FadeTransition is preferred over Opacity because Flutter's
              // compositing pipeline can optimize animated transitions better.
              // When a flipAnimation is provided from the parent controller,
              // it can drive this transition for further savings.
              child = FadeTransition(
                opacity: AlwaysStoppedAnimation<double>(opacity),
                child: child,
              );
            }
            return child;
          })(),
        ),
        // Layer 2: Middle (stationary content clipped to fold)
        _buildMiddleLayer(
          context: context,
          geo: geo,
          middleLayerContent: middleLayerContent,
          floatProgress: floatProgress,
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
              flapContentFadeOutEnd: flapContentFadeOutEnd,
              thinPaperStrength: thinPaperStrength,
              endRevealStrength: endRevealStrength,
              flapContentRevealStart: flapContentRevealStart,
              flapContentRevealEnd: flapContentRevealEnd,
              flapFrontImage: flapFrontImage,
              flapFrontSrcRect: flapFrontSrcRect,
              flapFrontSettleImage: flapFrontSettleImage,
              flapFrontSettleSrcRect: flapFrontSettleSrcRect,
              flapFrontDestRect: resolvedFlapDestRect,
              flapBackImage: flapBackImage,
              flapBackSrcRect: flapBackSrcRect,
              flapBackStrength: flapBackStrength,
              geo: geo,
              performanceProfile: performanceProfile,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) =>
      itemBuilder!(context, index);

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

    // CRITICAL: Never fall back to live _buildPage here. The OffscreenPreRenderer
    // widgets already render live pages for capture. Adding another live
    // itemBuilder call would cause Duplicate GlobalKey crashes.
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
  /// When a snapshot is not ready yet, an opaque paper underlay is shown
  /// to avoid Duplicate GlobalKey crashes from live widget trees appearing
  /// in both Offstage and drag-layer siblings of the same Stack.
  Widget _buildPageContent(BuildContext context, int index) {
    // Double-spread: full spread snapshots (current index is spread-only in PreRenderManager).
    if (isDoubleSpread) {
      final spreadImage = spreadSnapshots[index];
      if (spreadImage != null) {
        return _wrapWithConstraints(_buildSnapshotImage(spreadImage));
      }
    }

    // Single-page (or spread fallback): per-page snapshot
    final snapshot = pageSnapshots[index];
    if (snapshot != null) {
      return _wrapWithConstraints(_buildSnapshotImage(snapshot));
    }

    // Single-mode fallback: currentIndex is stored only in spreadSnapshots
    // (PreRenderManager._doCaptureSnapshots skips pageSnapshots for currentIndex).
    // Check spreadSnapshots before falling through to opaque paper.
    if (!isDoubleSpread) {
      final spreadFallback = spreadSnapshots[index];
      if (spreadFallback != null) {
        return _wrapWithConstraints(_buildSnapshotImage(spreadFallback));
      }
    }

    // CRITICAL: Never fall back to live _buildPage here. The Offstage widgets
    // (backgroundWidgets, currentPage) already render live pages for capture.
    // Adding another live itemBuilder call for the same index in the same Stack
    // would cause Duplicate GlobalKey crashes if the host's page widgets use
    // GlobalKeys internally (e.g. Form, TextEditingController, PageStorage).
    // Snapshots arrive within 1-2 frames via the PreRenderManager retry loop.
    return _buildOpaquePaperUnderlay(context);
  }

  /// Layer 2: stationary content clipped to the fold.
  Widget _buildMiddleLayer({
    required BuildContext context,
    required PageFlipGeometry geo,
    required Widget middleLayerContent,
    required double floatProgress,
  }) {
    if (!isDoubleSpread) {
      var middleOpacity = 1.0;
      if (floatProgress >= flapContentRevealEnd) {
        middleOpacity = 0.0;
      } else if (floatProgress >= flapContentRevealStart) {
        final divisor = flapContentRevealEnd - flapContentRevealStart;
        if (divisor > 0.001) {
          final t = (floatProgress - flapContentRevealStart) / divisor;
          middleOpacity = 1.0 - t * t * (3 - 2 * t);
        } else {
          middleOpacity = 0.0;
        }
      }

      Widget middle = ClipPath(
        clipper: PageFlipClipper(
          progress: floatProgress,
          isRightToLeft: true,
          touchOffset: touchPosition,
          isForward: isForward,
          geo: geo,
        ),
        child: middleLayerContent,
      );

      if (middleOpacity < 0.999) {
        middle = FadeTransition(
          opacity: AlwaysStoppedAnimation<double>(middleOpacity),
          child: middle,
        );
      }
      return middle;
    }

    // Double-spread: clip to stationary half if forward.
    // Backward flip needs the full spread because the unpeeled left page AND the right page are stationary.
    final Widget stationaryContent;
    if (isForward) {
      stationaryContent = clipFullSpreadHalf(
        alignment: Alignment.centerLeft,
        child: middleLayerContent,
      );
    } else {
      stationaryContent = middleLayerContent;
    }

    if (isForward) {
      return ClipPath(
        clipper: PageFlipClipper(
          progress: floatProgress,
          isRightToLeft: true,
          touchOffset: touchPosition,
          isDoubleSpread: true,
          geo: geo,
        ),
        child: stationaryContent,
      );
    }

    // Backward double-spread: stationary content clipped right-of-fold so
    // bottom layer's previous-spread content does not bleed onto the right side.
    return ClipPath(
      clipper: PageFlipOpenClipper(
        progress: floatProgress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: true,
        isForward: false,
        geo: geo,
      ),
      child: stationaryContent,
    );
  }
}

/// Helper widget that safely pushes pre-rendering widgets offscreen.
///
/// Disables focus, semantics, and pointer interactions so they do not leak into the active tree,
/// but keeps them in the paint tree so [RepaintBoundary] can capture snapshots successfully.
class OffscreenPreRenderer extends StatelessWidget {
  /// Creates an [OffscreenPreRenderer].
  const OffscreenPreRenderer({
    required this.child,
    required this.isOffscreen,
    super.key,
  });

  /// The child widget to render.
  final Widget child;

  /// True to push the child offscreen and isolate it.
  final bool isOffscreen;

  @override
  Widget build(BuildContext context) {
    if (!isOffscreen) return child;

    return Transform.translate(
      offset: const Offset(-20000, -20000),
      child: IgnorePointer(
        child: ExcludeFocus(
          child: ExcludeSemantics(
            child: child,
          ),
        ),
      ),
    );
  }
}
