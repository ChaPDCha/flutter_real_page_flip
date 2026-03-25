import 'package:flutter/material.dart';

// LAYOUT GATE: Single constraint gate (LayoutBuilder + needBounded -> SizedBox, constrainedSize to layer view).
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

import 'controllers/page_flip_state_controller.dart';
import 'effects/page_flip_engine.dart';
import 'managers/pre_render_manager.dart';
import 'models/page_flip_config.dart';
import 'models/page_flip_effect_handler.dart';
import 'page_flip_layer_view.dart';
import 'widgets/default_page_flip_effect_handler.dart';

export 'models/page_flip_config.dart';
import 'widgets/edge_tap_feedback.dart';

/// Controller for programmatic interaction with the [PageFlipWidget].
///
/// Allows you to trigger page flips (next, previous) or jump to a specific page
/// without requiring user gestures.
class PageFlipController {
  PageFlipWidgetState? _state;

  /// Flips to the next page, triggering the forward animation.
  /// If the current page is the last page, this has no effect.
  void nextPage() {
    _state?.nextPage();
  }

  /// Flips to the previous page, triggering the reverse animation.
  /// If the current page is the first page, this has no effect.
  void previousPage() {
    _state?.previousPage();
  }

  /// Instantly jumps to the specified [index] without a flip animation.
  Future<void> goToPage(int index) {
    return _state?.goToPage(index) ?? Future.value();
  }
}

/// A widget that provides a highly realistic, interactive 3D page flip effect.
///
/// It supports realistic shadows, specular highlights, synchronized sound
/// effects, and haptic feedback. Wrap your content pages in the [itemBuilder].
class PageFlipWidget extends StatefulWidget {
  /// Optional controller to programmatically change pages.
  final PageFlipController? controller;

  /// Configuration options for the physical behavior, aesthetics, and effects.
  final PageFlipConfig config;

  /// Builder for the pages. Returns the widget for the given [index].
  final IndexedWidgetBuilder itemBuilder;

  /// The total number of pages in the flip book.
  final int itemCount;

  /// The page index to display when the widget first builds.
  final int initialIndex;

  /// Callback fired when a page has completely finished flipping.
  final void Function(int pageNumber)? onPageFlipped;

  /// Callback fired the moment a flip animation or drag begins.
  final void Function()? onFlipStart;

  /// Callback fired immediately when the internal current page index changes.
  final void Function(int pageNumber)? onPageChanged;

  /// Callback to intercept and handle sensory effects (sound/haptics) manually.
  final void Function(
    PageFlipEvent effect, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
    int? timestampMs,
  })? onHandleEffect;

  /// Creates a [PageFlipWidget] with realistic Physics and effects.
  const PageFlipWidget({
    Key? key,
    this.controller,
    this.config = PageFlipConfig.defaultSettings,
    required this.itemBuilder,
    required this.itemCount,
    this.initialIndex = 0,
    this.onPageFlipped,
    this.onFlipStart,
    this.onPageChanged,
    this.onHandleEffect,
  })  : assert(initialIndex < itemCount,
            'initialIndex cannot be greater than itemCount'),
        super(key: key);

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

/// The state for [PageFlipWidget], managing rendering and events.
class PageFlipWidgetState extends State<PageFlipWidget>
    with TickerProviderStateMixin {
  late final PageFlipStateController _controller;
  final PreRenderManager _preRenderManager = PreRenderManager();

  int get _totalPages => widget.itemCount;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;

    _controller = PageFlipStateController(
      vsync: this,
      animationDuration: widget.config.duration,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onPageFinalized: _onPageFinalized,
      onEffectTrigger: _handleEffect,
    );
    _controller.setIndex(widget.initialIndex, _totalPages);
    _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);

    // Initialize Effect Handler
    _effectHandler = widget.config.effectHandler ??
        DefaultPageFlipEffectHandler(
          screenWidth: _controller.cachedWidth,
        );

    // Initial pre-render snapshots (requires layout to be complete)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captureSnapshots();
      }
    });
  }

  late PageFlipEffectHandler _effectHandler;

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._state = this;

    // Update effect handler if changed in config
    if (widget.config.effectHandler != oldWidget.config.effectHandler) {
      _effectHandler.dispose();
      _effectHandler = widget.config.effectHandler ??
          DefaultPageFlipEffectHandler(
            screenWidth: _controller.cachedWidth,
          );
    }

    // Redraw if content or count changes
    if (widget.itemBuilder != oldWidget.itemBuilder ||
        widget.itemCount != oldWidget.itemCount) {
      _controller.setIndex(_controller.currentIndex, _totalPages);

      // Reset pre-render manager to avoid using stale keys or snapshots
      _preRenderManager.reset();

      // Schedule a new capture frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
        if (mounted) setState(() {});
        _captureSnapshots();
      });

      setState(() {});
    } else {
      // Update pre-render keys for new structure if necessary (soft update)
      _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _preRenderManager.dispose();
    _effectHandler.dispose();
    super.dispose();
  }

  void _onPageFinalized(int newIndex) {
    widget.onPageChanged?.call(newIndex);
    widget.onPageFlipped?.call(newIndex);
    _preRenderManager.cleanup(newIndex, _totalPages);
    _preRenderManager.prepareKeys(newIndex, _totalPages);
    _captureSnapshots();
  }

  void _captureSnapshots() {
    _preRenderManager.captureSnapshots(
      _controller.currentIndex,
      _totalPages,
      () {
        if (mounted) setState(() {});
      },
    );
  }

  void _handleEffect(
    PageFlipEvent effect, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
    int? timestampMs,
  }) {
    if (widget.onHandleEffect != null) {
      widget.onHandleEffect!(
        effect,
        pageIndex: pageIndex ?? _controller.currentIndex,
        intensity: intensity,
        volume: volume,
        texture: texture,
        resistance: resistance,
        timestampMs: timestampMs,
      );
      return;
    }

    // Use toggles from config
    final isHaptic = effect.name.contains('Haptic') ||
        effect == PageFlipEvent.impulseHaptic; // Simple classification
    if (isHaptic && !widget.config.enableHaptics) return;
    if (effect == PageFlipEvent.sound && !widget.config.enableSound) return;

    _effectHandler.onHandleEffect(
      effect,
      pageIndex: pageIndex ?? _controller.currentIndex,
      intensity: intensity,
      volume: volume,
      texture: texture,
      resistance: resistance,
      timestampMs: timestampMs,
    );
  }

  // Public API methods via controller

  /// Triggers the forward page flip animation programmatically.
  void nextPage() {
    widget.onFlipStart?.call();
    if (widget.config.skipTapAnimation) {
      goToPage(_controller.currentIndex + 1);
    } else {
      _controller.triggerTapFlip(true, _totalPages);
    }
  }

  /// Triggers the backward page flip animation programmatically.
  void previousPage() {
    widget.onFlipStart?.call();
    if (widget.config.skipTapAnimation) {
      goToPage(_controller.currentIndex - 1);
    } else {
      _controller.triggerTapFlip(false, _totalPages);
    }
  }

  /// Jumps instantly to the [index] without an animation.
  Future<void> goToPage(int index) async {
    if (index < 0 || index >= _totalPages) return;
    widget.onFlipStart?.call();

    // Immediate jump for now, as drag logic is complex to simulate
    setState(() {
      _controller.setIndex(index, _totalPages);
    });

    _onPageFinalized(index);
  }

  @override
  Widget build(BuildContext context) {
    // Update cached width for controller logic
    return LayoutBuilder(
      builder: (context, constraints) {
        _controller.updateCachedWidth(constraints.maxWidth);

        // Sync screen width to effect handler for physics normalization
        if (_effectHandler is DefaultPageFlipEffectHandler) {
          (_effectHandler as DefaultPageFlipEffectHandler).screenWidth =
              constraints.maxWidth;
        }

        // Single constraint gate: prevent unbounded height/width from propagating
        // (e.g. Scaffold body first frame, Stack without bounded parent).
        // All descendants (including Offstage pages) then receive finite constraints.
        final needBounded =
            !constraints.maxHeight.isFinite || !constraints.maxWidth.isFinite;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final effectiveWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxW;

        final constrainedSize = Size(maxW, maxH);

        final view = PageFlipLayerView(
          itemBuilder: widget.itemBuilder,
          itemCount: _totalPages,
          currentIndex: _controller.currentIndex,
          dragProgress: _controller.dragProgress,
          isDragging: _controller.isDragging,
          isForward: _controller.isForward,
          touchPosition: _controller.touchPosition,
          pageSnapshots: _preRenderManager.pageSnapshots,
          pageKeys: _preRenderManager.pageKeys,
          paperFlapColor: widget.config.backgroundColor,
          constrainedSize: constrainedSize,
        );

        final mainContent = Stack(
          fit: StackFit.expand,
          children: [
            view,
            // Left Edge Tap (Previous Page)
            if (widget.config.edgeTapWidthRatio > 0 &&
                widget.config.enableSwipe)
              EdgeTapFeedback(
                isLeftEdge: true,
                width: effectiveWidth * widget.config.edgeTapWidthRatio,
                label: widget.config.edgeTapPreviousLabel ?? 'Previous page',
                hint: widget.config.edgeTapPreviousHint ??
                    'Tap to go to previous page',
                onTap: () {
                  if (_controller.currentIndex > 0) {
                    previousPage();
                  }
                },
              ),
            // Right Edge Tap (Next Page)
            if (widget.config.edgeTapWidthRatio > 0 &&
                widget.config.enableSwipe)
              EdgeTapFeedback(
                isLeftEdge: false,
                width: effectiveWidth * widget.config.edgeTapWidthRatio,
                label: widget.config.edgeTapNextLabel ?? 'Next page',
                hint: widget.config.edgeTapNextHint ?? 'Tap to go to next page',
                onTap: () {
                  if (_controller.currentIndex < _totalPages - 1) {
                    nextPage();
                  }
                },
              ),
          ],
        );

        final childWidget = (!widget.config.enableSwipe)
            ? mainContent
            : RawGestureDetector(
                gestures: {
                  PageFlipGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                          PageFlipGestureRecognizer>(
                    () => PageFlipGestureRecognizer(
                        sensitivity: widget.config.sensitivity),
                    (PageFlipGestureRecognizer instance) {
                      instance.onStart =
                          (d) => _controller.onDragStart(d, _totalPages);
                      instance.onUpdate =
                          (d) => _controller.onDragUpdate(d, _totalPages);
                      instance.onEnd =
                          (d) => _controller.onDragEnd(d, _totalPages);
                      instance.onCancel =
                          () => _controller.onDragCancel(_totalPages);
                    },
                  ),
                },
                child: mainContent,
              );

        final semantics = Semantics(
          label: widget.config.semanticBuilder?.call(
                _controller.currentIndex + 1,
                _totalPages,
              ) ??
              'Page ${_controller.currentIndex + 1} of $_totalPages',
          value: '${_controller.currentIndex + 1}',
          increasedValue: '${_controller.currentIndex + 2}',
          decreasedValue: '${_controller.currentIndex}',
          onIncrease:
              _controller.currentIndex < _totalPages - 1 ? nextPage : null,
          onDecrease: _controller.currentIndex > 0 ? previousPage : null,
          onScrollLeft:
              _controller.currentIndex < _totalPages - 1 ? nextPage : null,
          onScrollRight: _controller.currentIndex > 0 ? previousPage : null,
          child: childWidget,
        );
        if (needBounded) {
          return SizedBox(width: maxW, height: maxH, child: semantics);
        }
        return semantics;
      },
    );
  }
}
