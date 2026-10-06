import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
// LAYOUT GATE: Single constraint gate (LayoutBuilder + needBounded -> SizedBox, constrainedSize to layer view).
// Do not remove. See README_LAYOUT_CONSTRAINTS.md in package root and docs/flutter_layout_constraints_guide.md.

import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/page_flip_sound_player.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';
import 'package:real_page_flip/src/widgets/edge_tap_feedback.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

export 'models/page_flip_config.dart';

/// Controller for programmatic page navigation on a [PageFlipWidget].
class PageFlipController {
  PageFlipWidgetState? _state;

  /// Returns true if this controller is currently attached to an active [PageFlipWidgetState].
  bool get isAttached => _state != null;

  /// Navigates to the next page.
  ///
  /// Like every navigation call, ignored at the book boundary and while a
  /// finger or another turn owns the page; a refused call reports no
  /// `onFlipStart` / `onFlipEnd`.
  void nextPage() {
    _state?.nextPage();
  }

  /// Navigates to the previous page. See [nextPage] for refusal rules.
  void previousPage() {
    _state?.previousPage();
  }

  /// Navigates to the specified page index. See [nextPage] for refusal rules.
  Future<void> goToPage(int index) => _state?.goToPage(index) ?? Future.value();

  /// Marks one page's live content as changed.
  ///
  /// When [prewarm] is true, a replacement snapshot is captured asynchronously
  /// if the page is in the live capture window. Set it to false for transient
  /// content that should be refreshed only if the user actually starts a flip.
  void markPageDirty(int index, {bool prewarm = true}) =>
      _state?._markPageDirty(index, prewarm: prewarm);

  /// Marks the currently visible page snapshot stale.
  void markCurrentPageDirty({bool prewarm = true}) =>
      _state?._markCurrentPageDirty(prewarm: prewarm);
}

/// A high-fidelity, physics-based page flip widget for Flutter.
///
/// Displays a book-like page-flipping interface with drag and tap gestures.
/// Supports dark mode, haptic feedback, sound effects, and custom
/// effect handlers.
class PageFlipWidget extends StatefulWidget {
  /// Creates a [PageFlipWidget] with the given pages and configuration.
  PageFlipWidget({
    required this.itemBuilder,
    required this.itemCount,
    super.key,
    this.controller,
    this.contentRevision,
    this.config = PageFlipConfig.defaultSettings,
    this.initialIndex = 0,
    @Deprecated('Use spreadMode: PageFlipSpreadMode.doubleSpread.')
    this.isDoubleSpread = false,
    PageFlipSpreadMode? spreadMode,
    @Deprecated('Use onPageChanged, which fires at the same moment.')
    this.onPageFlipped,
    this.onFlipStart,
    this.onFlipEnd,
    this.onPageChanged,
    this.onHandleEffect,
    this.onEffectError,
  })  : spreadMode = spreadMode ??
            PageFlipSpreadModeCompat.fromIsDoubleSpread(
              isDoubleSpread: isDoubleSpread,
            ),
        assert(
          itemCount >= 0,
          'itemCount cannot be negative',
        ),
        assert(
          initialIndex >= 0,
          'initialIndex cannot be negative',
        ),
        assert(
          itemCount == 0 || initialIndex < itemCount,
          'initialIndex cannot be greater than itemCount',
        );

  /// Optional external controller for programmatic navigation.
  final PageFlipController? controller;

  /// Declarative content revision for the visible capture window.
  ///
  /// Changing this value keeps the widget state, controller index, and page
  /// keys intact while asynchronously replacing stale snapshots. For a single
  /// changed page, prefer [PageFlipController.markPageDirty].
  final Object? contentRevision;

  /// Configuration for animations, gestures, haptics, and effects.
  final PageFlipConfig config;

  /// Builder for individual page widgets.
  final IndexedWidgetBuilder itemBuilder;

  /// Total number of pages.
  final int itemCount;

  /// Index of the initially visible page.
  final int initialIndex;

  /// True if rendering for a dual spread book (legacy; prefer [spreadMode]).
  @Deprecated('Use spreadMode: PageFlipSpreadMode.doubleSpread.')
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
  @Deprecated('Use onPageChanged, which fires at the same moment.')
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

  /// Custom callback for handling raw effects. Overrides the built-in handler.
  ///
  /// This observer receives all effect events even when [PageFlipConfig]
  /// disables built-in sound or haptics, allowing hosts to implement an
  /// entirely custom policy. Use [PageFlipConfig.effectHandler] when the
  /// engine's enable/disable gates should remain authoritative.
  final FutureOr<void> Function(
    PageFlipEvent effect, {
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  })? onHandleEffect;

  /// Called when an effect handler throws or completes with an error.
  ///
  /// The engine keeps page navigation alive after haptic/audio failures, but
  /// production apps can use this callback to log or surface integration issues
  /// instead of losing them in debug output.
  final void Function(
    PageFlipEvent effect,
    Object error,
    StackTrace stackTrace,
  )? onEffectError;

  @override
  PageFlipWidgetState createState() => PageFlipWidgetState();
}

/// State class for [PageFlipWidget] that manages animation and effects.
class PageFlipWidgetState extends State<PageFlipWidget>
    with TickerProviderStateMixin {
  late final PageFlipStateController _controller;

  /// Fires for every flip frame: progress ticks and touch movement.
  late final Listenable _flipFrameListenable;
  final PreRenderManager _preRenderManager = PreRenderManager();
  Size? _lastConstrainedSize;
  bool _isInternalEffectHandler = false;
  bool _pendingLayoutCallback = false;
  bool _pendingSnapshotRefresh = false;
  bool _snapshotRefreshScheduled = false;
  bool _snapshotRefreshImmediate = false;

  int get _totalPages => widget.itemCount < 0 ? 0 : widget.itemCount;

  PageFlipConfig? _configSource;
  PageFlipConfig _normalizedConfig = PageFlipConfig.defaultSettings;

  /// Normalized config, memoized per [PageFlipWidget.config] instance.
  ///
  /// `normalized` allocates and deep-compares a ~40-field config. It used to
  /// run on every access — several times per build and per pointer event.
  PageFlipConfig get _config {
    final source = widget.config;
    if (!identical(source, _configSource)) {
      _configSource = source;
      _normalizedConfig = source.normalized;
    }
    return _normalizedConfig;
  }

  /// Exposes the internal state controller for advanced programmatic interaction.
  PageFlipStateController get controller => _controller;

  /// Dirty snapshot indices exposed for performance regression tests.
  @visibleForTesting
  Set<int> get debugDirtySnapshotIndices => _preRenderManager.dirtyIndices;

  /// Number of successful asynchronous captures in this widget's lifetime.
  @visibleForTesting
  int get debugAsyncSnapshotCaptureCount =>
      _preRenderManager.successfulAsyncCaptureCount;

  /// Number of successful synchronous captures in this widget's lifetime.
  @visibleForTesting
  int get debugSyncSnapshotCaptureCount =>
      _preRenderManager.successfulSyncCaptureCount;

  /// Physical raster size retained for [index], exposed for resolution tests.
  @visibleForTesting
  ({int width, int height})? debugSnapshotPixelSize(int index) {
    final image = _preRenderManager.spreadSnapshots[index] ??
        _preRenderManager.pageSnapshots[index];
    if (image == null) return null;
    return (width: image.width, height: image.height);
  }

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    final config = _config;

    _controller = PageFlipStateController(
      vsync: this,
      animationDuration: config.duration,
      cutoffForward: config.cutoffForward,
      cutoffPrevious: config.cutoffPrevious,
      onUpdate: () {
        if (mounted) setState(() {});
      },
      onPageFinalized: _onPageFinalized,
      onEffectTrigger: _handleEffect,
      onFlipStart: _onFlipStart,
      onFlipEnd: _onFlipEnd,
    );
    _flipFrameListenable = Listenable.merge(<Listenable>[
      _controller.progressNotifier,
      _controller.touchNotifier,
    ]);
    _controller.setIndex(widget.initialIndex, _totalPages);
    _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
    // Initialize Effect Handler
    _isInternalEffectHandler = config.effectHandler == null;
    _effectHandler = config.effectHandler ??
        DefaultPageFlipEffectHandler(
          hapticTexturePreset: config.hapticTexturePreset,
          hapticQuality: config.hapticQuality,
          hapticStrength: config.hapticStrength,
        );

    // Warm snapshots immediately after first frame. Using immediate capture
    // (no debounce) so snapshots are ready before the user's first drag gesture.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _captureSnapshots(immediate: true);
        _warmUpSound();
      }
    });
  }

  /// The player that will receive [PageFlipEvent.sound], if the engine knows
  /// it: the host's `soundPlayer`, else the default handler's own player.
  /// A custom `effectHandler` manages its own audio and is not warmed here.
  PageFlipSoundPlayer? get _activeSoundPlayer {
    final hostSound = _config.soundPlayer;
    if (hostSound != null) return hostSound;
    final handler = _effectHandler;
    return handler is DefaultPageFlipEffectHandler ? handler.soundPlayer : null;
  }

  /// Preloads the active sound so the first turn is not silent. Loading is
  /// idempotent for the default player; nothing loads while sound is off or
  /// when [PageFlipWidget.onHandleEffect] takes over all effects.
  void _warmUpSound() {
    if (!_config.enableSound || widget.onHandleEffect != null) return;
    final player = _activeSoundPlayer;
    if (player == null) return;
    try {
      final result = player.warmUp();
      if (result is Future<void>) {
        unawaited(
          result.catchError((Object error, StackTrace stackTrace) {
            _reportEffectError(
              PageFlipEvent.sound,
              error,
              stackTrace,
              'soundPlayer.warmUp',
            );
          }),
        );
      }
    } on Object catch (error, stackTrace) {
      _reportEffectError(
        PageFlipEvent.sound,
        error,
        stackTrace,
        'soundPlayer.warmUp',
      );
    }
  }

  void _onFlipStart() {
    widget.onFlipStart?.call();

    // Refresh the CURRENT page snapshot from its live boundary so the flip turns
    // the page from the user's present scroll position, not the stale top-of-page
    // capture taken when the chapter loaded. Synchronous so the first flip frame
    // already shows the scrolled content (see [PreRenderManager.refreshIndexSync]).
    final shouldRefreshCurrent =
        _config.snapshotRefreshPolicy == PageFlipSnapshotRefreshPolicy.always ||
            _preRenderManager.isDirty(_controller.currentIndex);
    if (mounted && shouldRefreshCurrent) {
      _preRenderManager.refreshIndexSync(
        _controller.currentIndex,
        pixelRatio: _capturePixelRatio(),
      );
    }

    // A turn that starts before the recapture for a new viewport shape has
    // landed would draw the old proportions for its whole length: the
    // background refresh waits for the turn to end. Retake those pages now,
    // synchronously like the current page above (no GPU readback).
    final viewport = _lastConstrainedSize;
    if (mounted && viewport != null) {
      for (final index in _preRenderManager.indicesOutOfShape(
        _controller.currentIndex,
        _totalPages,
        viewport,
      )) {
        _preRenderManager.refreshIndexSync(
          index,
          pixelRatio: _capturePixelRatio(),
        );
      }
    }

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
    _notifyHost(widget.onFlipEnd);
    final deferred = _deferredStructuralChange;
    if (deferred != null && mounted && !_isFlipActive) {
      _deferredStructuralChange = null;
      _applyStructuralChange(deferred);
    }
    if (_pendingSnapshotRefresh) {
      _scheduleSnapshotRefresh(immediate: true);
    }
  }

  void _handleSizeChange(Size newSize) {
    final previous = _lastConstrainedSize;
    if (previous == null) {
      _lastConstrainedSize = newSize;
      return;
    }
    if (previous == newSize) return;
    _lastConstrainedSize = newSize;
    // Mark stale instead of flushing. Flushing disposed every image
    // immediately — including ones an in-flight flip's painter still
    // references (keyboard insets and rotation can resize mid-turn) — and
    // left the next flip with blank paper until the async recapture landed.
    // Stale images stay until their replacement succeeds, and the refresh
    // itself waits for any active flip to end.
    _preRenderManager.markDirtyWindow(_controller.currentIndex, _totalPages);
    // A fold, an unfold or a rotation changes the page's shape in one step,
    // and until the recapture lands every stale snapshot is drawn stretched
    // into the new viewport. Replace those at once. The small per-frame steps
    // of a window drag or a typical keyboard animation keep the debounce, so
    // they do not capture on every frame.
    _scheduleSnapshotRefresh(
      immediate: PreRenderManager.resizeDistortsSnapshots(previous, newSize),
    );
  }

  double? _lastDependencyPixelRatio;

  /// The platform's "reduce motion" setting, as last read from [MediaQuery].
  bool _systemReducesMotion = false;

  /// Whether turns are currently shortened: the platform setting is on and the
  /// host has not opted out through [PageFlipConfig.respectReducedMotion].
  bool _reducedMotion = false;

  /// Settle duration while motion is reduced: effectively instant.
  static const Duration _reducedMotionDuration = Duration(milliseconds: 1);

  Duration get _effectiveDuration =>
      _reducedMotion ? _reducedMotionDuration : _config.duration;

  /// Whether programmatic turns skip the animation: by choice
  /// ([PageFlipConfig.skipTapAnimation]) or because motion is reduced.
  bool get _instantTurns => _config.skipTapAnimation || _reducedMotion;

  void _syncReducedMotion() {
    final reduce = _config.respectReducedMotion && _systemReducesMotion;
    if (reduce == _reducedMotion) return;
    _reducedMotion = reduce;
    _applyTimingSettings();
  }

  void _applyTimingSettings() {
    final config = _config;
    _controller.updateSettings(
      animationDuration: _effectiveDuration,
      cutoffForward: config.cutoffForward,
      cutoffPrevious: config.cutoffPrevious,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Registers the DPR dependency and recaptures when it changes (e.g. a
    // desktop window dragged to a monitor with a different scale factor).
    // Snapshots otherwise kept the old resolution until an unrelated refresh.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context);
    final previous = _lastDependencyPixelRatio;
    _lastDependencyPixelRatio = pixelRatio;
    if (previous != null && pixelRatio != previous) {
      _preRenderManager.markDirtyWindow(_controller.currentIndex, _totalPages);
      _scheduleSnapshotRefresh(immediate: true);
    }
    // Follows the system "reduce motion" setting, including live changes.
    _systemReducesMotion =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncReducedMotion();
  }

  late PageFlipEffectHandler _effectHandler;

  @override
  void didUpdateWidget(PageFlipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldController = oldWidget.controller;
      if (identical(oldController?._state, this)) {
        oldController?._state = null;
      }
    }
    widget.controller?._state = this;
    // Read the old memoized value BEFORE `_config` switches to the new source.
    final oldConfig = identical(oldWidget.config, _configSource)
        ? _normalizedConfig
        : oldWidget.config.normalized;
    final config = _config;

    final wasReduced = _reducedMotion;
    _reducedMotion = config.respectReducedMotion && _systemReducesMotion;
    if (config.duration != oldConfig.duration ||
        config.cutoffForward != oldConfig.cutoffForward ||
        config.cutoffPrevious != oldConfig.cutoffPrevious ||
        _reducedMotion != wasReduced) {
      _applyTimingSettings();
    }

    // Update effect handler if changed in config, or if we are using the default
    // handler and the performance profile or texture preset has changed.
    final effectHandlerChanged =
        config.effectHandler != oldConfig.effectHandler;
    final profileChanged =
        config.performanceProfile != oldConfig.performanceProfile;
    final snapshotResolutionChanged =
        _capturePixelRatioFor(config) != _capturePixelRatioFor(oldConfig);
    final texturePresetChanged =
        config.hapticTexturePreset != oldConfig.hapticTexturePreset;
    final hapticQualityChanged =
        config.hapticQuality != oldConfig.hapticQuality;
    final hapticStrengthChanged =
        config.hapticStrength != oldConfig.hapticStrength;
    var handlerRecreated = false;
    if (effectHandlerChanged ||
        (config.effectHandler == null &&
            (profileChanged ||
                texturePresetChanged ||
                hapticQualityChanged ||
                hapticStrengthChanged))) {
      if (_isInternalEffectHandler &&
          !effectHandlerChanged &&
          !profileChanged &&
          (texturePresetChanged ||
              hapticQualityChanged ||
              hapticStrengthChanged) &&
          _effectHandler is DefaultPageFlipEffectHandler) {
        (_effectHandler as DefaultPageFlipEffectHandler).updateConfig(
          hapticTexturePreset: config.hapticTexturePreset,
          hapticQuality: config.hapticQuality,
          hapticStrength: config.hapticStrength,
        );
      } else {
        handlerRecreated = true;
        if (_isInternalEffectHandler) {
          _effectHandler.dispose();
        }
        _isInternalEffectHandler = config.effectHandler == null;
        _effectHandler = config.effectHandler ??
            DefaultPageFlipEffectHandler(
              hapticTexturePreset: config.hapticTexturePreset,
              hapticQuality: config.hapticQuality,
              hapticStrength: config.hapticStrength,
            );
      }
    }

    if (handlerRecreated ||
        config.enableSound != oldConfig.enableSound ||
        config.soundPlayer != oldConfig.soundPlayer ||
        widget.onHandleEffect != oldWidget.onHandleEffect) {
      _warmUpSound();
    }

    // An external jump is the host ASKING for a different page, which it can
    // only express by CHANGING [initialIndex]. Comparing the incoming
    // `initialIndex` against `_controller.currentIndex` alone cannot tell that
    // apart from the ordinary, correct state of affairs after the engine has
    // advanced a page on its own: the host's own notion of position does not
    // move until `onPageChanged` tells it to, and hosts routinely take another
    // frame (or an async hop) to act on that. Any unrelated rebuild in that
    // window — an inherited-widget change, or the host's own `onFlipStart`
    // handler calling `setState` — then arrived carrying an `initialIndex`
    // that merely had not caught up yet, and was obeyed as a jump: the engine
    // rewound the page turn it had just performed AND `reset()` cleared
    // `pageKeys`, so `_LivePageCaptureLayer` skipped every adjacent index
    // (`if (pageKey == null) continue;`) and unmounted both neighbours for a
    // frame. Text-heavy pages then re-shaped every `RenderParagraph` on the
    // next frame, which readers see as the text blinking out and back.
    // Regression coverage: page_flip_host_rebuild_during_flip_test.dart.
    //
    // Requiring `initialIndex` to have actually changed keeps every genuine
    // external navigation working (a host jumping somewhere must change it by
    // definition) while making the engine indifferent to rebuilds that say
    // nothing new about position.
    final indexChangedExternally =
        widget.initialIndex != oldWidget.initialIndex &&
            widget.initialIndex != _controller.currentIndex;
    final contentRevisionChanged =
        widget.contentRevision != oldWidget.contentRevision;
    // Do not reset on itemBuilder identity: hosts often pass a new closure each
    // build; snapshots are refreshed on flip start and after page changes.
    final itemCountChanged = widget.itemCount != oldWidget.itemCount;
    final spreadModeChanged = widget.spreadMode != oldWidget.spreadMode;

    if (itemCountChanged || spreadModeChanged || indexChangedExternally) {
      final change = _StructuralChange(
        jumpTo: indexChangedExternally ? widget.initialIndex : null,
        layoutChanged: spreadModeChanged,
      );
      // A spread-mode switch gives every index a new meaning (page 7 becomes
      // spread 3), so a turn in the air can never finish validly under it: its
      // destination would reach the host as an index of the OLD numbering,
      // after the host already counts in the new one. Such a turn is ended,
      // like one whose pages were removed.
      if (_isFlipActive && !spreadModeChanged && _inFlightTurnStillValid()) {
        // Never restructure under a page that is in the air: resetting here
        // disposed the snapshots the flip was painting and moved
        // `currentIndex` mid-turn, so the finalize then advanced from the
        // wrong page. Merge and apply once the turn ends (see _onFlipEnd).
        _deferredStructuralChange =
            _deferredStructuralChange?.mergedWith(change) ?? change;
        _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
      } else {
        final pending = _deferredStructuralChange;
        _deferredStructuralChange = null;
        if (_isFlipActive) {
          // The turn cannot finish validly under the new structure: its
          // current or destination page is gone, or every index now means a
          // different page. Letting it run on used to finalize
          // `currentIndex ± 1` past the new last page (the host's
          // `itemBuilder` was asked for an index it no longer has) or report
          // an index of the old numbering. `onFlipEnd` still fires once;
          // `onPageChanged` does not.
          _controller.cancelActiveFlip();
        }
        _applyStructuralChange(pending?.mergedWith(change) ?? change);
      }
    } else {
      // Update pre-render keys for new structure if necessary (soft update)
      _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
      if (contentRevisionChanged || snapshotResolutionChanged) {
        _preRenderManager.markDirtyWindow(
          _controller.currentIndex,
          _totalPages,
        );
        _scheduleSnapshotRefresh(immediate: true);
      }
    }
  }

  _StructuralChange? _deferredStructuralChange;

  /// Whether both ends of the in-flight turn still exist under the new count.
  ///
  /// Deferral is only safe while they do. If the host shrank the book below
  /// the current page or the turn's destination, the live layer would build
  /// out-of-range indices for the rest of the turn, so the change is applied
  /// immediately instead (the pre-2.4 behaviour).
  bool _inFlightTurnStillValid() {
    final current = _controller.currentIndex;
    final destination = _controller.isForward ? current + 1 : current - 1;
    return current < _totalPages &&
        destination >= 0 &&
        destination < _totalPages;
  }

  /// Applies an item-count / spread-mode / external-index change.
  ///
  /// A pure count change that leaves the current page where it was (the
  /// common lazy-loading append) keeps the key window and stale snapshots
  /// alive and only marks them dirty — no unmount, no blank flap. Anything
  /// that changes WHAT the current page is (an external jump, a clamp after
  /// shrinking, a spread-mode switch) resets the snapshot cache.
  void _applyStructuralChange(_StructuralChange change) {
    final previousIndex = _controller.currentIndex;
    _controller.setIndex(change.jumpTo ?? previousIndex, _totalPages);
    final pageIdentityChanged =
        change.layoutChanged || _controller.currentIndex != previousIndex;

    if (!pageIdentityChanged) {
      _preRenderManager
        ..cleanup(_controller.currentIndex, _totalPages)
        ..prepareKeys(_controller.currentIndex, _totalPages)
        ..markDirtyWindow(_controller.currentIndex, _totalPages);
      _scheduleSnapshotRefresh(immediate: true);
      setState(() {});
      return;
    }

    // Reset pre-render manager to avoid using stale keys or snapshots
    _preRenderManager.reset();

    // Repopulate the key window SYNCHRONOUSLY, before this frame builds.
    // The post-frame callback below is too late on its own: `reset()` empties
    // `pageKeys`, and `_LivePageCaptureLayer` skips any adjacent index whose
    // key is missing, so an empty map for even one frame unmounts both
    // neighbours — and the next frame inflates them from scratch. Restoring
    // the window here keeps them in the tree across the reset, which also
    // lets a host that keys its own page subtrees re-parent them instead of
    // rebuilding. The post-frame call is still needed for the capture pass
    // and is harmless: `prepareKeys` is `putIfAbsent`-based.
    _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);

    // Schedule a new capture frame. The cache was just emptied, so there is
    // nothing stale to protect and nothing to debounce: wait only for the
    // frame that mounts the new pages. A debounced capture here would also
    // supersede an immediate one already in flight (a shape jump a frame
    // earlier) and leave the book without snapshots for 300 ms.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _preRenderManager.prepareKeys(_controller.currentIndex, _totalPages);
        setState(() {});
        _captureSnapshots(immediate: true);
      }
    });

    setState(() {});
  }

  @override
  void dispose() {
    final externalController = widget.controller;
    if (identical(externalController?._state, this)) {
      externalController?._state = null;
    }
    _controller.dispose();
    _preRenderManager.dispose();
    if (_isInternalEffectHandler) {
      _effectHandler.dispose();
    }
    super.dispose();
  }

  void _onPageFinalized(int newIndex) {
    widget.onPageChanged?.call(newIndex);
    widget.onPageFlipped?.call(newIndex);
    _preRenderManager.cleanup(newIndex, _totalPages);
    _preRenderManager.prepareKeys(newIndex, _totalPages);

    // Capture only after the new live/offstage page window has painted.
    _scheduleSnapshotRefresh(immediate: true);
  }

  /// Device pixel ratio for snapshot capture, scaled down by performance profile.
  double _capturePixelRatio() => _capturePixelRatioFor(_config);

  double _capturePixelRatioFor(PageFlipConfig config) {
    // Depend on the DPR aspect only: a full MediaQuery dependency rebuilt this
    // widget for unrelated changes (keyboard insets, text scale, padding).
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final profileRatio = switch (config.effectiveSnapshotPerformanceProfile) {
      DevicePerformanceProfile.low => pixelRatio.clamp(1.0, 1.25),
      DevicePerformanceProfile.medium => pixelRatio.clamp(1.0, 2.0),
      DevicePerformanceProfile.high => pixelRatio,
    };
    final maxRatio = config.maxSnapshotPixelRatio;
    final requestedRatio =
        maxRatio != null && profileRatio > maxRatio ? maxRatio : profileRatio;
    final constrainedSize = _lastConstrainedSize;
    if (constrainedSize == null) return requestedRatio;
    return _preRenderManager.effectiveSnapshotPixelRatio(
      constrainedSize,
      requestedRatio,
    );
  }

  bool get _isFlipActive =>
      _controller.isDragging ||
      _controller.animationController.isAnimating ||
      _controller.isPendingFinalize;

  void _markCurrentPageDirty({bool prewarm = true}) =>
      _markPageDirty(_controller.currentIndex, prewarm: prewarm);

  void _markPageDirty(int index, {bool prewarm = true}) {
    if (index < 0 || index >= _totalPages) return;
    _preRenderManager.markDirty(index);

    // A page outside current ±1 has no mounted capture boundary. Keep its dirty
    // marker until navigation brings it into the live window.
    if (prewarm && (index - _controller.currentIndex).abs() <= 1) {
      _scheduleSnapshotRefresh(immediate: true);
    }
  }

  bool _onCurrentPageScroll(ScrollNotification notification) {
    if (_config.snapshotRefreshPolicy !=
        PageFlipSnapshotRefreshPolicy.whenDirty) {
      return false;
    }

    _preRenderManager.markDirty(_controller.currentIndex);
    if (notification is ScrollEndNotification) {
      _scheduleSnapshotRefresh(immediate: true);
    }
    return false;
  }

  void _scheduleSnapshotRefresh({required bool immediate}) {
    _pendingSnapshotRefresh = true;
    // A request that cannot wait must not be downgraded by an earlier,
    // debounced one whose post-frame callback has not run yet.
    _snapshotRefreshImmediate = _snapshotRefreshImmediate || immediate;
    if (_snapshotRefreshScheduled || _isFlipActive) return;

    _snapshotRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapshotRefreshScheduled = false;
      if (!mounted) return;
      if (_isFlipActive) return;

      _pendingSnapshotRefresh = false;
      final captureNow = _snapshotRefreshImmediate;
      _snapshotRefreshImmediate = false;
      _captureSnapshots(immediate: captureNow);
    });
    // addPostFrameCallback does not itself request a frame when this API is
    // called from an idle host controller.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _captureSnapshots({bool immediate = false}) {
    if (!mounted) return;
    final pixelRatio = _capturePixelRatio();

    _preRenderManager.captureSnapshots(
      _controller.currentIndex,
      _totalPages,
      () {
        // Snapshots updated — no-op; next flip will use fresh captures.
      },
      immediate: immediate,
      includeCurrentSpread: true,
      capturePageSnapshotClones: !widget.spreadMode.isDoubleSpread,
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
    final config = _config;
    if (widget.onHandleEffect != null) {
      try {
        final result = widget.onHandleEffect!(
          effect,
          intensity: intensity,
          volume: volume,
          texture: texture,
          resistance: resistance,
        );
        if (result is Future) {
          unawaited(
            result.catchError((Object error, StackTrace stackTrace) {
              _reportEffectError(effect, error, stackTrace, 'onHandleEffect');
            }),
          );
        }
      } on Object catch (error, stackTrace) {
        _reportEffectError(effect, error, stackTrace, 'onHandleEffect');
      }
      return;
    }

    // Classify effect type by explicit enum check (not string name) for
    // refactor-safety — a renamed enum member silently breaks string matching.
    final isHaptic = switch (effect) {
      PageFlipEvent.startHaptic ||
      PageFlipEvent.stopHaptic ||
      PageFlipEvent.continuousHaptic ||
      PageFlipEvent.texturedHaptic ||
      PageFlipEvent.impulseHaptic ||
      PageFlipEvent.detentHaptic =>
        true,
      _ => false,
    };
    if (isHaptic &&
        (!config.enableHaptics ||
            config.hapticTexturePreset == PaperTexturePreset.none)) {
      return;
    }
    if (effect == PageFlipEvent.sound && !config.enableSound) return;

    // A host sound player replaces only the sound; haptics keep flowing to
    // the effect handler (default or custom).
    final hostSound = config.soundPlayer;
    if (effect == PageFlipEvent.sound && hostSound != null) {
      try {
        final result = hostSound.play(volume: volume ?? 1.0);
        if (result is Future<void>) {
          unawaited(
            result.catchError((Object error, StackTrace stackTrace) {
              _reportEffectError(effect, error, stackTrace, 'soundPlayer');
            }),
          );
        }
      } on Object catch (error, stackTrace) {
        _reportEffectError(effect, error, stackTrace, 'soundPlayer');
      }
      return;
    }

    try {
      final handlerResult = _effectHandler.onHandleEffect(
        effect,
        pageIndex: _controller.currentIndex,
        intensity: intensity,
        volume: volume,
        texture: texture,
        resistance: resistance,
      );
      if (handlerResult is Future) {
        unawaited(
          handlerResult.catchError((Object error, StackTrace stackTrace) {
            _reportEffectError(effect, error, stackTrace, 'effectHandler');
          }),
        );
      }
    } on Object catch (error, stackTrace) {
      _reportEffectError(effect, error, stackTrace, 'effectHandler');
    }
  }

  void _reportEffectError(
    PageFlipEvent effect,
    Object error,
    StackTrace stackTrace,
    String source,
  ) {
    widget.onEffectError?.call(effect, error, stackTrace);
    // Hosts get the error through onEffectError; the console copy is for
    // development only so a failing effect cannot flood release logs.
    if (kDebugMode) debugPrint('PageFlip $source error: $error');
  }

  /// Instant (non-animated) turn that still reports the flip lifecycle.
  ///
  /// Fires the HOST's `onFlipStart`, not [_onFlipStart]: the latter prepares
  /// snapshots for an animated turn (a synchronous `toImageSync` of the
  /// current page plus an adjacent capture pass), which is pure GPU waste
  /// when no frame of the turn is ever drawn. `goToPage` schedules the
  /// post-navigation capture the next turn actually needs.
  void _jumpWithFlipLifecycle(int target) {
    // A refused jump (book boundary, or a gesture/turn already owns the page)
    // is not a turn: report no lifecycle for it, exactly like the animated
    // path, whose `triggerTapFlip` refuses silently.
    if (!_canJumpTo(target)) return;
    widget.onFlipStart?.call();
    goToPage(target);
    _onFlipEnd();
  }

  /// Whether [goToPage] would navigate to [index] right now.
  bool _canJumpTo(int index) =>
      index >= 0 &&
      index < _totalPages &&
      index != _controller.currentIndex &&
      !_controller.isBusy;

  /// Calls a host lifecycle callback, deferring it past the current build.
  ///
  /// A turn can be aborted from `didUpdateWidget` (the host shrank the book
  /// under it). Host callbacks commonly call `setState`, which is illegal on
  /// an ancestor while the framework is building, so they run after the frame.
  void _notifyHost(VoidCallback? callback) {
    if (callback == null) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      return;
    }
    callback();
  }

  // -- Keyboard and mouse wheel (both opt-in) ------------------------------

  /// Events closer together than this belong to one wheel gesture.
  static const Duration _wheelBurstGap = Duration(milliseconds: 250);

  /// Scrolled distance (logical pixels) within one wheel gesture that turns a
  /// page. Small enough for one mouse notch, large enough to ignore a graze.
  static const double _wheelTurnDistance = 20;

  Duration? _lastWheelEventTime;
  double _wheelDelta = 0;
  bool _wheelTurned = false;

  Widget _withKeyboard(PageFlipConfig config, Widget child) =>
      config.enableKeyboardNavigation
          ? Focus(autofocus: true, onKeyEvent: _onKeyEvent, child: child)
          : child;

  Widget _withWheel(PageFlipConfig config, Widget child) =>
      config.enableWheelNavigation
          ? Listener(onPointerSignal: _onPointerSignal, child: child)
          : child;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    // Shortcuts such as Ctrl+Home belong to the host.
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final shift = keyboard.isShiftPressed;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        (key == LogicalKeyboardKey.space && !shift)) {
      nextPage();
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp ||
        (key == LogicalKeyboardKey.space && shift)) {
      previousPage();
    } else if (key == LogicalKeyboardKey.home) {
      _jumpWithFlipLifecycle(0);
    } else if (key == LogicalKeyboardKey.end) {
      _jumpWithFlipLifecycle(_totalPages - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Ctrl or Cmd with the wheel is zoom in browsers and many desktop apps.
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed) return;
    // Only the first registered handler acts on a signal. Content deeper in the
    // tree registers first, so a scrollable page that can still scroll keeps
    // its wheel; at its end, or on a page that does not scroll, the book turns.
    GestureBinding.instance.pointerSignalResolver
        .register(event, _turnFromWheel);
  }

  void _turnFromWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final scroll = event.scrollDelta;
    final delta = scroll.dy.abs() >= scroll.dx.abs() ? scroll.dy : scroll.dx;
    if (delta == 0) return;

    // One turn per burst of events: a mouse notch, or the long tail of a
    // trackpad fling, must not skip several pages.
    final previous = _lastWheelEventTime;
    _lastWheelEventTime = event.timeStamp;
    if (previous == null || event.timeStamp - previous > _wheelBurstGap) {
      _wheelDelta = 0;
      _wheelTurned = false;
    }
    if (_wheelTurned) return;

    _wheelDelta += delta;
    if (_wheelDelta.abs() < _wheelTurnDistance) return;
    _wheelTurned = true;
    if (_wheelDelta > 0) {
      nextPage();
    } else {
      previousPage();
    }
  }

  /// Navigates to the next page, animating the flip unless
  /// [PageFlipConfig.skipTapAnimation] is set or the system reduces motion
  /// (see [PageFlipConfig.respectReducedMotion]).
  void nextPage() {
    if (_instantTurns) {
      _jumpWithFlipLifecycle(_controller.currentIndex + 1);
    } else {
      _controller.triggerTapFlip(isNext: true, totalPages: _totalPages);
    }
  }

  /// Navigates to the previous page. See [nextPage] for when it animates.
  void previousPage() {
    if (_instantTurns) {
      _jumpWithFlipLifecycle(_controller.currentIndex - 1);
    } else {
      _controller.triggerTapFlip(isNext: false, totalPages: _totalPages);
    }
  }

  /// Jumps directly to the given page index without animation.
  ///
  /// Unlike `nextPage()` / `previousPage()`, this is a low-level direct jump that
  /// does NOT fire `onFlipStart` / `onFlipEnd` callbacks. It is intended for
  /// programmatic navigation where gesture lifecycle callbacks are not desired.
  /// The `onPageChanged` callback still fires so consumers can update UI state.
  ///
  /// Ignored for an out-of-range or current [index], and while a finger or a
  /// turn owns the page (`PageFlipStateController.isBusy`).
  Future<void> goToPage(int index) async {
    // Refused while a finger, drag, settle, or pending finalize owns the page:
    // a jump under an owned turn would let two actors drive one page.
    if (!_canJumpTo(index)) return;

    setState(() {
      _controller.setIndex(index, _totalPages);
    });
    _onPageFinalized(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final config = _config;
          // Single constraint gate: prevent unbounded height/width from propagating
          // (e.g. Scaffold body first frame, Stack without bounded parent).
          // All descendants (including Offstage pages) then receive finite constraints.
          final needBounded =
              !constraints.maxHeight.isFinite || !constraints.maxWidth.isFinite;
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final flipDragExtent =
              widget.spreadMode.isDoubleSpread ? maxW / 2 : maxW;
          final maxH = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final effectiveWidth =
              constraints.maxWidth.isFinite ? constraints.maxWidth : maxW;

          final constrainedSize = Size(maxW, maxH);

          // PERFORMANCE & STABILITY: Defer layout-driven state modifications
          // to a post-frame callback so they do not occur during active build passes.
          // Deduplicate via _pendingLayoutCallback to prevent stacking multiple
          // callbacks when LayoutBuilder.build() is called multiple times per frame.
          if (!_pendingLayoutCallback) {
            _pendingLayoutCallback = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _pendingLayoutCallback = false;
              if (mounted) {
                _controller.updateCachedWidth(flipDragExtent);
                _controller.updateCachedHeight(maxH);
                _effectHandler.viewportWidth = flipDragExtent;
                _handleSizeChange(constrainedSize);
              }
            });
          }

          // PERFORMANCE: flip layers update through a ValueListenableBuilder so they
          // rebuild independently of the parent widget tree. During animation frames,
          // only the animated layers (PageFlipLayerView) are rebuilt — EdgeTapFeedback,
          // PageFlipGestureLayer, and Semantics stay unchanged.
          // progressNotifier fires every animation tick; isDragging/touch/forward
          // are read from the controller getters (always current in memory).
          final livePageLayer = _LivePageCaptureLayer(
            itemBuilder: widget.itemBuilder,
            itemCount: _totalPages,
            currentIndex: _controller.currentIndex,
            pageKeys: _preRenderManager.pageKeys,
            constrainedSize: constrainedSize,
            progressListenable: _controller.progressNotifier,
            isDragging: () => _controller.isDragging,
            onCurrentPageScroll: _onCurrentPageScroll,
          );
          // Rebuild on touch movement too, not only on progress: the fold angle
          // is steered by the touch's vertical position, and a purely vertical
          // finger movement leaves progress unchanged.
          final animatedFlipLayer = AnimatedBuilder(
            animation: _flipFrameListenable,
            child: livePageLayer,
            builder: (context, livePages) => PageFlipLayerView(
              itemBuilder: widget.itemBuilder,
              itemCount: _totalPages,
              currentIndex: _controller.currentIndex,
              dragProgress: _controller.progressNotifier.value,
              isDragging: _controller.isDragging,
              isForward: _controller.isForward,
              touchPosition: _controller.touchPosition,
              pageSnapshots: _preRenderManager.pageSnapshots,
              spreadSnapshots: _preRenderManager.spreadSnapshots,
              pageKeys: _preRenderManager.pageKeys,
              paperFlapColor: config.backgroundColor,
              paperOpacity: config.paperOpacity,
              flapContentFadeOutEnd: config.flapContentFadeOutEnd,
              thinPaperStrength: config.thinPaperStrength,
              endRevealStrength: config.endRevealStrength,
              flapContentRevealStart: config.flapContentRevealStart,
              flapContentRevealEnd: config.flapContentRevealEnd,
              flapBackStrength: config.flapBackStrength,
              doubleSpreadMidFoldBleed: config.doubleSpreadMidFoldBleed,
              stationaryOverlayPainter: config.stationaryOverlayPainter,
              stationaryOverlayOwnsCenterGutter:
                  config.stationaryOverlayOwnsCenterGutter,
              singlePageBackContentOpacity: config.singlePageBackContentOpacity,
              enableSinglePageSettleReveal: config.enableSinglePageSettleReveal,
              constrainedSize: constrainedSize,
              isDoubleSpread: widget.spreadMode.isDoubleSpread,
              performanceProfile: config.performanceProfile,
              flipAnimation: _controller.animationController,
              livePageLayer: livePages,
            ),
          );

          final mainContent = Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                ignoring: _controller.blocksContentPointers,
                child: animatedFlipLayer,
              ),
              // Left Edge Tap (Previous Page)
              if (config.edgeTapWidthRatio > 0 && config.enableSwipe)
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: effectiveWidth * config.edgeTapWidthRatio,
                  label: config.edgeTapPreviousLabel ?? 'Previous page',
                  hint: config.edgeTapPreviousHint ??
                      'Tap to go to previous page',
                  onTap: () {
                    if (_controller.currentIndex > 0) {
                      previousPage();
                    }
                  },
                ),
              // Right Edge Tap (Next Page)
              if (config.edgeTapWidthRatio > 0 && config.enableSwipe)
                EdgeTapFeedback(
                  isLeftEdge: false,
                  width: effectiveWidth * config.edgeTapWidthRatio,
                  label: config.edgeTapNextLabel ?? 'Next page',
                  hint: config.edgeTapNextHint ?? 'Tap to go to next page',
                  onTap: () {
                    if (_controller.currentIndex < _totalPages - 1) {
                      nextPage();
                    }
                  },
                ),
              // Last in stack (center): raw pointer flip above selectable content.
              if (config.enableSwipe)
                PageFlipGestureLayer(
                  controller: _controller,
                  sensitivity: config.sensitivity,
                  totalPages: _totalPages,
                ),
            ],
          );

          final semantics = Semantics(
            label: config.semanticBuilder?.call(
                  _controller.currentIndex + 1,
                  _totalPages,
                ) ??
                'Page ${_controller.currentIndex + 1} of $_totalPages',
            value: '${_controller.currentIndex + 1}',
            // Only announce values the matching action can reach: at the last
            // page there is no "page N+1", at the first no "page 0".
            increasedValue: _controller.currentIndex < _totalPages - 1
                ? '${_controller.currentIndex + 2}'
                : null,
            decreasedValue: _controller.currentIndex > 0
                ? '${_controller.currentIndex}'
                : null,
            onIncrease:
                _controller.currentIndex < _totalPages - 1 ? nextPage : null,
            onDecrease: _controller.currentIndex > 0 ? previousPage : null,
            onScrollLeft:
                _controller.currentIndex < _totalPages - 1 ? nextPage : null,
            onScrollRight: _controller.currentIndex > 0 ? previousPage : null,
            child: _withKeyboard(config, _withWheel(config, mainContent)),
          );
          if (needBounded) {
            return SizedBox(width: maxW, height: maxH, child: semantics);
          }
          return semantics;
        },
      );
}

/// Hosts the expensive live current/adjacent page trees outside the animated
/// flip-layer builder. Only the lightweight offscreen wrapper reacts to frame
/// progress; host [IndexedWidgetBuilder] content is rebuilt on structural page
/// changes, not at 60/120 Hz.
class _LivePageCaptureLayer extends StatelessWidget {
  const _LivePageCaptureLayer({
    required this.itemBuilder,
    required this.itemCount,
    required this.currentIndex,
    required this.pageKeys,
    required this.constrainedSize,
    required this.progressListenable,
    required this.isDragging,
    required this.onCurrentPageScroll,
  });

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final int currentIndex;
  final Map<int, GlobalKey> pageKeys;
  final Size constrainedSize;
  final ValueListenable<double> progressListenable;
  final bool Function() isDragging;
  final NotificationListenerCallback<ScrollNotification> onCurrentPageScroll;

  Widget _constrain(Widget child) => SizedBox(
        width: constrainedSize.width,
        height: constrainedSize.height,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final currentBoundary = RepaintBoundary(
      key: pageKeys[currentIndex],
      child: NotificationListener<ScrollNotification>(
        onNotification: onCurrentPageScroll,
        child: _constrain(itemBuilder(context, currentIndex)),
      ),
    );
    final currentPage = ValueListenableBuilder<double>(
      valueListenable: progressListenable,
      child: currentBoundary,
      builder: (context, progress, child) => OffscreenPreRenderer(
        isOffscreen: progress > 0 && isDragging(),
        child: child!,
      ),
    );

    final backgroundPages = <Widget>[];
    for (final index in <int>{
      if (currentIndex > 0) currentIndex - 1,
      if (currentIndex < itemCount - 1) currentIndex + 1,
    }) {
      final pageKey = pageKeys[index];
      if (pageKey == null) continue;
      backgroundPages.add(
        OffscreenPreRenderer(
          isOffscreen: true,
          child: RepaintBoundary(
            key: pageKey,
            child: _constrain(itemBuilder(context, index)),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[...backgroundPages, currentPage],
    );
  }
}

/// A structural input change that arrived while a flip may be in the air.
@immutable
class _StructuralChange {
  const _StructuralChange({
    required this.jumpTo,
    required this.layoutChanged,
  });

  /// Externally requested page (a changed `initialIndex`), if any.
  final int? jumpTo;

  /// Whether the spread mode changed (page identity changes for every index).
  final bool layoutChanged;

  /// Combines two pending changes; the most recent jump wins.
  _StructuralChange mergedWith(_StructuralChange newer) => _StructuralChange(
        jumpTo: newer.jumpTo ?? jumpTo,
        layoutChanged: layoutChanged || newer.layoutChanged,
      );
}
