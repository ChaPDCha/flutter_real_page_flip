import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'effects/page_flip_engine.dart';

// LAYOUT GATE: constrainedSize + _wrapWithConstraints for Offstage/current/flip pages.
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

/// Renders the page layers (Bottom, Middle, Flap) based on the current drag state.
class PageFlipLayerView extends StatelessWidget {
  const PageFlipLayerView({
    this.itemBuilder,
    required this.itemCount,
    required this.currentIndex,
    required this.dragProgress,
    required this.isDragging,
    required this.isForward,
    required this.touchPosition,
    required this.pageSnapshots,
    required this.pageKeys,
    this.paperFlapColor,
    this.constrainedSize,
    super.key,
  });

  final IndexedWidgetBuilder? itemBuilder;
  final int itemCount;
  final int currentIndex;
  final double dragProgress;
  final bool isDragging;
  final bool isForward;
  final Offset touchPosition;
  final Map<int, ui.Image> pageSnapshots;
  final Map<int, GlobalKey> pageKeys;
  final Color? paperFlapColor;

  /// Optional explicit size to constrain children (prevents infinite height from Stack).
  final Size? constrainedSize;

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
    final keyedCurrentPage = KeyedSubtree(
      key: currentKey,
      child: _wrapWithConstraints(
        RepaintBoundary(child: _buildPage(context, currentIndex)),
      ),
    );

    // Background pre-renders: Only build CURRENT window (prev, next)
    // to avoid layout overhead of 1000s of Offstage pages.
    final backgroundWidgets = <Widget>[];

    // Windowing: Only keep -1 and +1 in the tree
    final windowIndices = {
      if (currentIndex > 0) currentIndex - 1,
      if (currentIndex < itemCount - 1) currentIndex + 1,
    };

    for (final index in windowIndices) {
      final key = pageKeys[index];
      if (key == null) continue;

      // If we are NOT flipping to this page, keep it in Offstage
      if (!(dragProgress > 0 && isDragging)) {
        backgroundWidgets.add(
          Offstage(
            child: _wrapWithConstraints(
              RepaintBoundary(key: key, child: _buildPage(context, index)),
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
      middleLayerContent = keyedCurrentPage;
      bottomLayerContent = nextPageContent ?? const SizedBox.shrink();
    } else {
      middleLayerContent = previousPageContent ?? const SizedBox.shrink();
      bottomLayerContent = keyedCurrentPage;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ...backgroundWidgets,
        ClipPath(
          clipper: PageFlipOpenClipper(
            progress: floatProgress,
            isRightToLeft: true,
            touchOffset: touchPosition,
          ),
          child: bottomLayerContent,
        ),
        ClipPath(
          clipper: PageFlipClipper(
            progress: floatProgress,
            isRightToLeft: true,
            touchOffset: touchPosition,
          ),
          child: middleLayerContent,
        ),
        IgnorePointer(
          child: CustomPaint(
            size: constrainedSize ?? Size.infinite,
            painter: PageFlipPainter(
              progress: floatProgress,
              isRightToLeft: true,
              touchOffset: touchPosition,
              paperBackColor:
                  paperFlapColor ?? Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    return itemBuilder!(context, index);
  }

  Widget _buildPageContent(BuildContext context, int index) {
    final snapshot = pageSnapshots[index];
    if (snapshot != null) {
      return RawImage(image: snapshot, fit: BoxFit.cover);
    }
    return _wrapWithConstraints(
      RepaintBoundary(child: _buildPage(context, index)),
    );
  }
}
