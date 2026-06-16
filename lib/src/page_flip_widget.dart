import 'dart:async';

import 'package:flutter/material.dart';
// LAYOUT GATE: Single constraint gate (LayoutBuilder + needBounded -> SizedBox, constrainedSize to layer view).
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';
import 'package:real_page_flip/src/widgets/edge_tap_feedback.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

export 'models/page_flip_config.dart';

/// Controller for programmatic page navigation on a [PageFlipWidget].
class PageFlipController {
  PageFlipWidgetState? _state;

  /// Navigates to the next page.
  void nextPage() {
    _state?.nextPage();
  }

  /// Navigates to the previous page.
  void previousPage() {
    _state?.previousPage();
  }

  /// Navigates to the specified page index.
  Future<void> goToPage(int index) => _state?.goToPage(index) ?? Future.value();
}

/// A high-fidelity, physics-based page flip widget for Flutter.
///
/// Displays a book-like page-flipping interface with drag and tap gestures.
/// Supports dark mode, haptic feedback, sound effects, and custom
/// effect handlers.
class PageFlipWidget extends StatefulWidget {
  /// Creates a [PageFlipWidget] with the given pages and configuration.
  PageFlipWidget({
    required this.itemBuilder, required this.itemCount, super.key,
    this.controller,
    this.config = PageFlipConfig.defaultSettings,
    this.initialIndex = 0,
    this.isDoubleSpread = false,
    PageFlipSpreadMode? spreadMode,
    this.onPageFlipped,
    this.onFlipStart,
    this.onFlipEnd,
    this.onPageChanged,
    this.onHandleEffect,
  })  : spreadMode = spreadMode ??
            PageFlipSpreadModeCompat.fromIsDoubleSpread(isDoubleSpread),
        assert(initialIndex < itemCount,
            'initialIndex cannot be greater than itemCount',);

  /// Optional external controller for programmatic navigation.
  final PageFlipController? controller;

  /// Configuration for animations, gestures, haptics, and effects.
  final PageFlipConfig config;

  /// Builder for individual page widgets.
  final IndexedWidgetBuilder itemBuilder;

  /// Total number of pages.
  final int itemCount;

  /// Index of the initially visible page.
  final int initialIndex;

  /// True if rendering for a dual spread book (legacy; prefer [spreadMode]).
  final bool isDoubleSpread;

  /// Spread layout mode (defaults from [isDoubleSpread] when omitted).
  final PageFlipSpreadMode spreadMode;

  /// Called when a page flip animation completes successfully.
  ///
  /// The `pageNumber` parameter is the new current page index.
  ///
  /// This fires at the same time as [onPageChanged]. Prefer [onPageChanged]
  /// for reacting to page transitions; [onPageFlipped] is kept for
  /// backward compatibility.
  final void Function(int pageNumber)? onPageFlipped;

  /// Called when a flip gesture starts (drag or tap).
  final void Function()? onFlipStart;

  /// Called when a flip gesture or animation completes (whether successful or cancelled).
  final void Function()? onFlipEnd;

  /// Called when the current page index changes.
  ///
  /// The `pageNumber` parameter is the new page index.
  ///
  /// This is the primary callback for reacting to page transitions.
  /// See also [onPageFlipped] which fires at the same point.
  final void Function(int pageNumber)? onPageChanged;
  /// Custom callback for handling effects. Overrides the built-in handler.
  final FutureOr<void> Function(
    PageFlipEvent effect, {
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  })? onHandleEffect;

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

/// State class for [PageFlipWidget] that manages animation and effects.
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
      cutoffForward: widget.config.cutoffForward,
      cutoffPrevious: widget.config.cutoffPrevious,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onPageFinalized: _onPageFinalized,
      onEffectTrigger: _handleEffect,
      onFlipStart: _onFlipStart,
      onFlipEnd: _onFlipEnd,
    );
    _controller.setIndex(widget.initialIndex, _totalPages);
    _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
    // Initialize Effect Handler
    _effectHandler =
        widget.config.effectHandler ?? DefaultPageFlipEffectHandler();

    // Warm snapshots immediately after first frame. Using immediate capture
    // (no debounce) so snapshots are ready before the user's first drag gesture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captureSnapshots(immediate: true);
      }
    });
  }

  void _onFlipStart() {
    widget.onFlipStart?.call();
    if (!_preRenderManager.hasAdjacentSnapshots(
      _controller.currentIndex,
      _totalPages,
      includeCurrentSpread: true,
    )) {
      // Defer GPU readback (boundary.toImage) to after the current frame
      // renders. During a drag start, the GPU is busy rendering the first
      // animation frame; triggering a readback synchronously would flush the
      // GPU pipeline and drop frames on low-end devices. By deferring to a
      // post-frame callback, the first frame renders uninterrupted and the
      // snapshot arrives 1-2 frames later (still early in the drag).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _captureSnapshots(immediate: true);
        }
      });
    }
  }

  void _onFlipEnd() {
    widget.onFlipEnd?.call();
  }

  late final PageFlipEffectHandler _effectHandler;

  // Incremented on every didUpdateWidget so ValueListenableBuilder below can
  // use it as a key to force rebuild when itemBuilder dependencies change
  // (e.g. theme, font size — the itemBuilder reference itself is stable).
  int _flipLayerVersion = 0;

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?._state = this;

    // Bump version so ValueListenableBuilder key changes on parent rebuild,
    // forcing the flip layers to rebuild with fresh itemBuilder output.
    _flipLayerVersion++;

    // Update effect handler if changed in config
    if (widget.config.effectHandler != oldWidget.config.effectHandler) {
      _effectHandler.dispose();
      _effectHandler =
          widget.config.effectHandler ?? DefaultPageFlipEffectHandler();
    }

    final indexChangedExternally = widget.initialIndex != _controller.currentIndex;
    // Do not reset on itemBuilder identity: hosts often pass a new closure each
    // build; snapshots are refreshed on flip start and after page changes.
    final contentOrCountChanged = widget.itemCount != oldWidget.itemCount ||
        widget.spreadMode != oldWidget.spreadMode;

    // Redraw if content, count, or initialIndex changed externally
    if (contentOrCountChanged || indexChangedExternally) {
      final newIndex = indexChangedExternally ? widget.initialIndex : _controller.currentIndex;
      _controller.setIndex(newIndex, _totalPages);

      // Reset pre-render manager to avoid using stale keys or snapshots
      _preRenderManager.reset();

      // Schedule a new capture frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
          setState(() {});
          _captureSnapshots();
        }
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

    // Defer snapshot capture to a post-frame callback.
    // This ensures that the widget tree has rebuilt and painted the new page
    // onstage (and the previous page offstage, preserving its last painted texture)
    // before we attempt to capture repaint boundaries.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captureSnapshots(immediate: true);
      }
    });
  }

  void _captureSnapshots({bool immediate = false}) {
    if (!mounted) return;
    final mediaQuery = MediaQuery.maybeOf(context);
    final pixelRatio = mediaQuery?.devicePixelRatio ?? 1.0;
    _preRenderManager.captureSnapshots(
      _controller.currentIndex,
      _totalPages,
      () {
        // Snapshots updated — no-op; next flip will use fresh captures.
      },
      immediate: immediate,
      includeCurrentSpread: true,
      pixelRatio: pixelRatio,
    );
  }

  void _handleEffect(
    PageFlipEvent effect, {
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {
    if (widget.onHandleEffect != null) {
      final result = widget.onHandleEffect!(
        effect,
        intensity: intensity,
        volume: volume,
        texture: texture,
        resistance: resistance,
      );
      if (result is Future) {
        result.catchError((Object e) {
          debugPrint('PageFlip onHandleEffect error: $e');
        });
      }
      return;
    }

    // Use toggles from config
    final isHaptic = effect.name.contains('Haptic') ||
        effect == PageFlipEvent.impulseHaptic; // Simple classification
    if (isHaptic && !widget.config.enableHaptics) return;
    if (effect == PageFlipEvent.sound && !widget.config.enableSound) return;

    final handlerResult = _effectHandler.onHandleEffect(
      effect,
      pageIndex: _controller.currentIndex,
      intensity: intensity,
      volume: volume,
      texture: texture,
      resistance: resistance,
    );
    if (handlerResult is Future) {
      handlerResult.catchError((Object e) {
        debugPrint('PageFlip effectHandler error: $e');
      });
    }
  }

  /// Navigates to the next page, animating the flip if [PageFlipConfig.skipTapAnimation] is false.
  void nextPage() {
    if (widget.config.skipTapAnimation) {
      goToPage(_controller.currentIndex + 1);
    } else {
      _controller.triggerTapFlip(true, _totalPages);
    }
  }

  /// Navigates to the previous page, animating the flip if [PageFlipConfig.skipTapAnimation] is false.
  void previousPage() {
    if (widget.config.skipTapAnimation) {
      goToPage(_controller.currentIndex - 1);
    } else {
      _controller.triggerTapFlip(false, _totalPages);
    }
  }

  /// Jumps directly to the given page index without animation.
  Future<void> goToPage(int index) async {
    if (index < 0 || index >= _totalPages) return;
    _onFlipStart();

    // Immediate jump for now, as drag logic is complex to simulate
    setState(() {
      _controller.setIndex(index, _totalPages);
    });

    _onPageFinalized(index);
    _onFlipEnd();
  }

  @override
  Widget build(BuildContext context) {
    // Update cached width for controller logic
    return LayoutBuilder(
      builder: (context, constraints) {
        // Single constraint gate: prevent unbounded height/width from propagating
        // (e.g. Scaffold body first frame, Stack without bounded parent).
        // All descendants (including Offstage pages) then receive finite constraints.
        final needBounded =
            !constraints.maxHeight.isFinite || !constraints.maxWidth.isFinite;
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final flipDragExtent = widget.spreadMode.isDoubleSpread
            ? maxW / 2
            : maxW;
        _controller.updateCachedWidth(flipDragExtent);
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final effectiveWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxW;

        final constrainedSize = Size(maxW, maxH);

        // PERFORMANCE: flip layers update through a ValueListenableBuilder so they
        // rebuild independently of the parent widget tree. During animation frames,
        // only the animated layers (PageFlipLayerView) are rebuilt — EdgeTapFeedback,
        // PageFlipGestureLayer, and Semantics stay unchanged.
        // progressNotifier fires every animation tick; isDragging/touch/forward
        // are read from the controller getters (always current in memory).
        final animatedFlipLayer = ValueListenableBuilder<double>(
          key: ValueKey(_flipLayerVersion),
          valueListenable: _controller.progressNotifier,
          builder: (context, progress, _) {
            return PageFlipLayerView(
              itemBuilder: widget.itemBuilder,
              itemCount: _totalPages,
              currentIndex: _controller.currentIndex,
              dragProgress: progress,
              isDragging: _controller.isDragging,
              isForward: _controller.isForward,
              touchPosition: _controller.touchPosition,
              pageSnapshots: _preRenderManager.pageSnapshots,
              spreadSnapshots: _preRenderManager.spreadSnapshots,
              pageKeys: _preRenderManager.pageKeys,
              paperFlapColor: widget.config.backgroundColor,
              paperOpacity: widget.config.paperOpacity,
              flapContentFadeOutEnd: widget.config.flapContentFadeOutEnd,
              flapContentRevealStart: widget.config.flapContentRevealStart,
              flapContentRevealEnd: widget.config.flapContentRevealEnd,
              constrainedSize: constrainedSize,
              isDoubleSpread: widget.spreadMode.isDoubleSpread,
            );
          },
        );

        final mainContent = Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              ignoring: _controller.blocksContentPointers,
              child: animatedFlipLayer,
            ),
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
            // Last in stack (center): raw pointer flip above selectable content.
            if (widget.config.enableSwipe)
              PageFlipGestureLayer(
                controller: _controller,
                sensitivity: widget.config.sensitivity,
                totalPages: _totalPages,
              ),
          ],
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
          child: mainContent,
        );
        if (needBounded) {
          return SizedBox(width: maxW, height: maxH, child: semantics);
        }
        return semantics;
      },
    );
  }
}
