import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

/// Events that can be triggered by the page flip engine for haptic/sound effects.
enum PageFlipEvent {
  /// Haptic feedback for the start of a drag gesture.
  startHaptic,

  /// Haptic feedback to stop/cancel any ongoing vibration.
  stopHaptic,

  /// Short impulse haptic for tap flips and page change confirmations.
  impulseHaptic,

  /// Continuous haptic feedback during active page dragging.
  continuousHaptic,

  /// 피드 포워드 햅틱 이벤트 (velocity + fold angle).
  /// texture: 폴드 각도 (0~1), resistance: 페이지 저항감 (0~1)
  texturedHaptic,

  /// A single crisp micro-tick fired the instant a drag crosses the success
  /// cutoff threshold — a "point of no return" confirmation the user feels
  /// before releasing, distinct from the continuous friction texture.
  detentHaptic,

  /// Sound effect trigger for page flip audio.
  sound
}

/// Minimum duration (ms) for a snap-back (cancelled/failed) flip animation.
///
/// Real paper still takes a visible moment to settle even when barely
/// lifted. The old code shared an 80ms floor with the fast-completion path,
/// so a small aborted drag (the common case: user changes their mind after a
/// short swipe) snapped back almost instantly — reading as an abrupt
/// "flicker" rather than a smooth paper return. Kept well below the default
/// [PageFlipStateController.animationDuration] (450ms) so it still feels
/// responsive, not sluggish.
const int _kMinSnapBackMs = 180;

/// Manages the state and animation of the PageFlip widget.
class PageFlipStateController {
  /// Creates a [PageFlipStateController] with the given callbacks and thresholds.
  PageFlipStateController({
    /// Ticker provider for the animation controller.
    required this.vsync,

    /// Duration of the flip animation.
    required this.animationDuration,

    /// Callback invoked on every animation tick or drag update.
    required this.onUpdate,

    /// Callback invoked when a page flip animation finalises.
    required this.onPageFinalized,

    /// Callback triggered for haptic/sound effects during flips.
    required this.onEffectTrigger,

    /// Called when a flip gesture begins (drag start or tap flip).
    this.onFlipStart,

    /// Called when a flip gesture or animation completes (whether successful or cancelled).
    this.onFlipEnd,

    /// Forward drag threshold. Drag must exceed this progress to complete
    /// a forward flip. Range [0, 1]. Default 0.4.
    this.cutoffForward = 0.4,

    /// Backward drag threshold. Drag must exceed this progress to complete
    /// a backward flip. Range [0, 1]. Default 0.4.
    this.cutoffPrevious = 0.4,
  }) {
    animationController = AnimationController(
      vsync: vsync,
      duration: animationDuration,
    );
    animationController.addListener(_onAnimationTick);
  }

  /// The [TickerProvider] used by the animation controller.
  final TickerProvider vsync;

  /// Duration of the flip animation.
  final Duration animationDuration;

  /// Callback invoked on every animation update.
  final VoidCallback onUpdate;

  /// Callback invoked when a page change is finalised.
  final ValueChanged<int> onPageFinalized;

  /// Forward drag threshold [0, 1] for completing a forward flip.
  final double cutoffForward;

  /// Backward drag threshold [0, 1] for completing a backward flip.
  final double cutoffPrevious;

  /// Callback for triggering haptic/sound effects during drag and flip.
  final Function(
    PageFlipEvent effect, {
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) onEffectTrigger;

  /// Called when a flip gesture begins (drag start or tap flip).
  final VoidCallback? onFlipStart;

  /// Called when a flip gesture or animation completes (whether successful or cancelled).
  final VoidCallback? onFlipEnd;

  /// Notified on every animation tick or drag update so the flip layer
  /// widget can rebuild independently of [onUpdate]'s full-tree rebuild.
  /// Access via a [ValueListenableBuilder] to avoid `setState` on every frame.
  final ValueNotifier<double> progressNotifier = ValueNotifier<double>(0);

  /// Notified when the touch position changes during a drag.
  final ValueNotifier<Offset> touchNotifier =
      ValueNotifier<Offset>(Offset.zero);

  /// The underlying animation controller driving flip transitions.
  late final AnimationController animationController;

  int _currentIndex = 0;
  double _dragProgress = 0;
  Offset _touchPosition = Offset.zero;
  bool _isForward = true;
  bool _isDragging = false;
  bool _blocksContentPointers = false;
  bool _hasPlayedSound = false;

  /// Whether the detent micro-tick has already fired for the current drag.
  /// One-shot per drag session (not per threshold crossing) so a finger that
  /// wiggles back and forth across the cutoff does not spam the tick.
  bool _hasFiredDetent = false;
  double _cachedWidth = 1;
  double _lastReleaseVelocity = 0;
  double _smoothedSpeed = 0;

  /// True while the 1-frame visual transition is pending after a successful flip.
  /// Blocks new drag/tap gestures during this window to prevent re-entrant state.
  bool _isPendingFinalize = false;

  /// Whether a pending finalize transition is in progress.
  /// External callers (e.g. `PageFlipWidget.goToPage()`) must check this before
  /// initiating programmatic navigation to avoid re-entrant state corruption.
  bool get isPendingFinalize => _isPendingFinalize;
  bool _isDisposed = false;

  /// The current (leftmost visible) page index.
  int get currentIndex => _currentIndex;

  /// Normalised drag progress from 0.0 to 1.0.
  double get dragProgress => _dragProgress;

  /// Last recorded touch position in local coordinates.
  Offset get touchPosition => _touchPosition;

  /// Whether the current drag direction is forward (right-to-left).
  bool get isForward => _isForward;

  /// Whether a drag gesture is currently active.
  bool get isDragging => _isDragging;

  /// True while a horizontal flip drag blocks hits to page content.
  bool get blocksContentPointers => _blocksContentPointers;

  /// Called when horizontal flip intent is detected (before [onDragStart]).
  void beginPointerCapture() {
    if (_blocksContentPointers) return;
    _blocksContentPointers = true;
    onUpdate();
  }

  /// Releases content hit blocking after flip drag ends or is canceled.
  void endPointerCapture() {
    if (!_blocksContentPointers) return;
    _blocksContentPointers = false;
    onUpdate();
  }

  /// Whether the page-flip sound has already been played for this drag.
  bool get hasPlayedSound => _hasPlayedSound;

  /// Cached width of the widget used for normalising drag deltas.
  double get cachedWidth => _cachedWidth;

  /// Sets the current page index, clamping within [0, totalPages).
  void setIndex(int index, int totalPages) {
    if (totalPages == 0) {
      _currentIndex = 0;
    } else {
      _currentIndex = index.clamp(0, totalPages - 1);
    }
  }

  void _onAnimationTick() {
    _dragProgress = animationController.value;
    progressNotifier.value = _dragProgress;
  }

  /// Updates the horizontal drag distance that maps to flip progress 0→1.
  ///
  /// In double-spread mode this should be half the viewport width (one turning
  /// page), matching [PageFlipGeometry] page width.
  void updateCachedWidth(double width) {
    if (!width.isFinite || width <= 0) return;
    _cachedWidth = width;
  }

  /// Maps accumulated horizontal pointer movement to normalised flip progress.
  @visibleForTesting
  double progressFromHorizontalDelta(double totalDx) {
    if (!_cachedWidth.isFinite || _cachedWidth <= 0) return 0;
    return (totalDx.abs() / _cachedWidth).clamp(0.0, 1.0);
  }

  /// Fires a one-shot [PageFlipEvent.detentHaptic] the instant [_dragProgress]
  /// first reaches the direction's success cutoff during the CURRENT drag.
  ///
  /// One-shot per drag (not per crossing): once fired, stays silent for the
  /// rest of the gesture even if the finger retreats below the cutoff and
  /// crosses again, so wiggling near the threshold does not spam ticks.
  void _maybeFireDetent() {
    if (_hasFiredDetent) return;
    final threshold = _isForward ? cutoffForward : cutoffPrevious;
    if (_dragProgress < threshold) return;
    _hasFiredDetent = true;
    onEffectTrigger(PageFlipEvent.detentHaptic);
  }

  /// Handles the start of a drag gesture for page flipping.
  ///
  /// [accumulatedTotalDx] is horizontal movement already consumed before flip
  /// intent was accepted (touch slop). Crediting it prevents under-counting
  /// progress when the user starts a decisive horizontal swipe.
  void onDragStart(
    DragStartDetails details,
    int totalPages, {
    double accumulatedTotalDx = 0,
  }) {
    if (animationController.isAnimating || _isPendingFinalize) return;

    onFlipStart?.call();
    _touchPosition = details.localPosition;
    _isDragging = false;
    _dragProgress = 0.0;
    _hasPlayedSound = false;
    _hasFiredDetent = false;

    if (accumulatedTotalDx.abs() > 0.5) {
      _isForward = accumulatedTotalDx < 0;
      if ((_isForward && _currentIndex >= totalPages - 1) ||
          (!_isForward && _currentIndex <= 0)) {
        onUpdate();
        return;
      }
      _isDragging = true;
      _dragProgress = progressFromHorizontalDelta(accumulatedTotalDx);
      final startIntensity =
          (accumulatedTotalDx.abs() * 5).clamp(10, 80).toInt();
      onEffectTrigger(PageFlipEvent.startHaptic, intensity: startIntensity);
      // Credited touch-slop movement can already land past the cutoff on the
      // very first frame (a fast decisive swipe) — check here too, not just
      // in onDragUpdate, so that case still gets its confirmation tick.
      _maybeFireDetent();
    }

    onUpdate();
  }

  /// Handles a drag update, updating progress and triggering textured haptics.
  void onDragUpdate(DragUpdateDetails details, int totalPages) {
    if (animationController.isAnimating || _isPendingFinalize) return;

    _touchPosition = details.localPosition;
    final delta = details.primaryDelta ?? details.delta.dx;

    if (!_isDragging && delta.abs() > 0.1) {
      _isDragging = true;
      _isForward = delta < 0;

      if ((_isForward && _currentIndex >= totalPages - 1) ||
          (!_isForward && _currentIndex <= 0)) {
        _isDragging = false;
        return;
      }
      final startIntensity = (delta.abs() * 5).clamp(10, 80).toInt();
      onEffectTrigger(PageFlipEvent.startHaptic, intensity: startIntensity);
    }

    if (_isDragging) {
      final width = _cachedWidth;
      // Fix: Use signed delta based on direction to allow reversing the gesture
      final progressDelta = (_isForward ? -delta : delta) / width;
      final oldProgress = _dragProgress;
      _dragProgress = (_dragProgress + progressDelta).clamp(0.0, 1.0);

      if (_dragProgress != oldProgress) {
        // [Unified Haptic Pipeline]
        // The controller sends raw velocity + fold progress to the
        // effect handler. The handler's physics engine generates its
        // own Perlin noise for paper texture — no redundant noise
        // generation here. `foldProgress` is derived from the actual
        // flip position so the physics engine's resistance model
        // receives a clean geometric signal.
        final currentSpeed = delta.abs();
        // Lighter smoothing (0.65 old / 0.35 new) tracks fingertip speed changes
        // more responsively than the old 50/50 blend, so fast flicks and slow
        // crawls read as distinct textures instead of a lagged average.
        _smoothedSpeed = (_smoothedSpeed * 0.65) + (currentSpeed * 0.35);

        // Emit on ANY real motion (the `_dragProgress != oldProgress` guard
        // above already excludes a stationary finger). The old `> 0.12` gate
        // muted slow drags entirely, so the continuous waveform starved and the
        // vibration died mid-drag whenever the finger crawled. A tiny floor
        // keeps sub-pixel jitter from emitting noise while still feeding the
        // buffer continuously across the whole speed range.
        if (_smoothedSpeed > 0.02) {
          // Fold progress (0–1): peaks at mid-flip for maximum resistance.
          final foldProgress = math.sin(_dragProgress * math.pi);

          // Speed factor: normalised drag velocity. Low floor (0.05) preserves
          // fine low-speed detail instead of quantising slow drags to 0.2.
          final speedFactor = (_smoothedSpeed / 15.0).clamp(0.05, 1.0);

          // Intensity scales smoothly with speed so fast flicks hit harder while
          // slow crawls still whisper. A gentle sqrt-like low-end (Weber-Fechner
          // is applied again downstream in the physics amplitude) keeps the
          // perceived step size even across the range.
          final speedComponent =
              math.sqrt(_smoothedSpeed.clamp(0.0, 40.0)) * 14;
          final baseIntensity = speedComponent.clamp(24.0, 110.0).toInt();
          final finalIntensity =
              (baseIntensity + (foldProgress * 22).toInt()).clamp(28, 140);

          onEffectTrigger(
            PageFlipEvent.texturedHaptic,
            intensity: finalIntensity,
            texture: foldProgress,
            resistance: speedFactor,
          );
        }
      }

      // Variable Sound Volume: Based on how far we've flipped
      if (_dragProgress > 0.1 && !_hasPlayedSound) {
        final flipSpeed = delta.abs();
        final dynamicVolume = (flipSpeed / 50.0).clamp(0.1, 1.0);
        onEffectTrigger(PageFlipEvent.sound, volume: dynamicVolume);
        _hasPlayedSound = true;
      }

      // Detent confirmation tick: fires once, the instant progress first
      // crosses the success cutoff, so the finger feels "this will commit"
      // before it ever leaves the screen.
      _maybeFireDetent();
    }
    // Propagate animation state via notifier — avoids full setState
    // for every animation frame (see PageFlipWidget / ValueListenableBuilder).
    progressNotifier.value = _dragProgress;
    touchNotifier.value = _touchPosition;
  }

  /// Handles the end of a drag, animating the flip to completion or snap-back.
  void onDragEnd(DragEndDetails details, int totalPages) {
    if (_isDisposed) return;
    if (!_isDragging) {
      endPointerCapture();
      onFlipEnd?.call();
      return;
    }

    final velocity =
        details.primaryVelocity ?? details.velocity.pixelsPerSecond.dx;
    _lastReleaseVelocity = velocity.abs();
    final isFastFlip = _lastReleaseVelocity > 300;
    final threshold = _isForward ? cutoffForward : cutoffPrevious;
    final isSuccess = isFastFlip || _dragProgress > threshold;

    // Sync animation value to current drag progress to prevent jumps
    animationController.value = _dragProgress;

    // Adaptive duration: scale inversely with release velocity so fast flicks
    // complete quickly (80-150ms) while slow releases use full duration (450ms).
    // Only the remaining progress distance is animated, keeping velocity smooth.
    // The floor differs by outcome: a successful fast flick benefits from a
    // snappy 80ms finish, but a snap-back (isSuccess=false) uses the higher
    // [_kMinSnapBackMs] floor so small aborted drags still visibly ease back
    // like real paper instead of vanishing almost instantly.
    final remainingProgress = isSuccess ? (1.0 - _dragProgress) : _dragProgress;
    final velocityScale = (_lastReleaseVelocity / 1000.0).clamp(0.5, 3.0);
    final maxMs = animationDuration.inMilliseconds;
    final minMs =
        isSuccess ? math.min(80, maxMs) : math.min(_kMinSnapBackMs, maxMs);
    final adaptiveMs =
        (maxMs * remainingProgress / velocityScale).clamp(minMs, maxMs).toInt();

    animationController
        .animateTo(
          isSuccess ? 1 : 0,
          duration: Duration(milliseconds: adaptiveMs),
          curve: const PaperFlipCurve(),
        )
        .then((_) => _finalizePageChange(isSuccess, totalPages));
  }

  /// Handles cancellation of a drag, snapping the page back.
  void onDragCancel(int totalPages) {
    if (_isDisposed) return;
    if (!_isDragging) {
      endPointerCapture();
      onFlipEnd?.call();
      return;
    }
    animationController.value = _dragProgress;
    // Snap-back: scale duration by remaining progress, floored at
    // [_kMinSnapBackMs] so small aborted drags still ease back visibly
    // instead of snapping almost instantly.
    final cancelMaxMs = animationDuration.inMilliseconds;
    final cancelMs = (cancelMaxMs * _dragProgress)
        .clamp(math.min(_kMinSnapBackMs, cancelMaxMs), cancelMaxMs)
        .toInt();
    // Defer finalize until the snap-back animation actually completes —
    // mirrors onDragEnd's `.then()`. Calling `_finalizePageChange` right here
    // (the old behaviour) reset `isDragging`/`dragProgress` to their idle
    // values on the SAME frame the animation started, so the flip layers were
    // torn down immediately regardless of the animation in flight: a hard
    // visual cut ("flicker") instead of the intended smooth return. This path
    // fires whenever the gesture is cancelled mid-drag (e.g. the arbitration
    // logic yields to vertical scrolling), not just on an explicit release.
    animationController
        .animateTo(
          0,
          duration: Duration(milliseconds: cancelMs),
          curve: const PaperFlipCurve(),
        )
        .then((_) => _finalizePageChange(false, totalPages));
  }

  /// Triggers a programmatic page flip (e.g. from edge tap or controller).
  void triggerTapFlip({required bool isNext, required int totalPages}) {
    if (_isDisposed) return;
    if (_isDragging || animationController.isAnimating || _isPendingFinalize) {
      return;
    }

    if ((isNext && _currentIndex >= totalPages - 1) ||
        (!isNext && _currentIndex <= 0)) {
      return;
    }

    _isForward = isNext;
    _isDragging = true;
    _dragProgress = 0.0;
    _hasPlayedSound = false;
    _hasFiredDetent = false;
    // Tap flips have no drag start, so set touch position to page vertical
    // centre for a neutral (zero) fold angle instead of inheriting stale
    // coordinates from a previous drag gesture.
    _touchPosition = Offset(0, _cachedWidth);

    onFlipStart?.call();

    // Propagate structural state (isDragging) before animation starts.
    // Subsequent animation frames come through progressNotifier from _onAnimationTick.
    onUpdate();
    progressNotifier.value = _dragProgress;

    animationController.stop();
    animationController.value = 0.0;
    onEffectTrigger(PageFlipEvent.sound);
    onEffectTrigger(PageFlipEvent.impulseHaptic);

    animationController
        .animateTo(
          1,
          duration: animationDuration,
          curve: const TapFlipCurve(),
        )
        .then((_) => _finalizePageChange(true, totalPages));
  }

  void _finalizePageChange(bool success, int totalPages) {
    if (_isDisposed) return;
    if (success) {
      // Save velocity for haptic calculation before resetting state.
      final releaseVelocity = _lastReleaseVelocity;

      // Prevent new drag or tap flips during the 1-frame transition window.
      _isPendingFinalize = true;

      // Non-visual effects fire immediately (haptics don't need frame sync).
      endPointerCapture();
      onEffectTrigger(PageFlipEvent.stopHaptic);

      // Trigger impulse haptic on successful flip.
      final impulseIntensity = releaseVelocity > 0
          ? (releaseVelocity / 4).clamp(15.0, 120.0).toInt()
          : 60;
      onEffectTrigger(PageFlipEvent.impulseHaptic, intensity: impulseIntensity);

      // Defer the visual state transition to the next frame.
      //
      // The current frame continues displaying the completed flip animation
      // (progress ≈ 1.0, PageFlipPainter early-returns at >= 0.999, the
      // revealed page is fully visible behind the invisible flap). Keeping
      // the OLD currentIndex and isDragging=true for one extra frame gives
      // Flutter an additional rendering pass so the new page's live widget
      // — already mounted Offstage for snapshot capture — completes its
      // first on-screen paint before becoming the visible currentPage.
      // Without this deferral the snapshot→live-widget swap and the
      // drag→static layout swap occur on the same frame, producing a
      // 1-2 frame visual pop ("flicker") from sub-pixel rendering
      // differences between raster snapshots and live widget paint.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isDisposed) return;
        _isPendingFinalize = false;

        if (_isForward) {
          _currentIndex++;
        } else {
          _currentIndex--;
        }

        // Reset ALL drag state atomically so the ValueListenableBuilder
        // never observes isDragging=true with progress=0, and the non-drag
        // view is built with consistent state on the next frame.
        _dragProgress = 0.0;
        _isDragging = false;
        animationController.value = 0.0;
        _hasPlayedSound = false;
        _hasFiredDetent = false;
        _lastReleaseVelocity = 0.0;

        onPageFinalized(_currentIndex);
        onUpdate();
        onFlipEnd?.call();
      });
      // Ensure a frame is scheduled so the post-frame callback above actually
      // runs. addPostFrameCallback alone does NOT schedule a frame — without
      // this, the callback would only fire when the next frame happens to be
      // requested by something else (e.g. animation, setState). In tests,
      // pumpAndSettle would stop before processing the deferred callback.
      WidgetsBinding.instance.scheduleFrame();
    } else {
      // Cancelled flip: snap back — no deferral needed since the visible
      // page doesn't change (no snapshot→live-widget transition).
      _lastReleaseVelocity = 0.0;
      _dragProgress = 0.0;
      animationController.value = 0.0;
      _isDragging = false;
      _hasPlayedSound = false;
      _hasFiredDetent = false;
      endPointerCapture();
      onEffectTrigger(PageFlipEvent.stopHaptic);
      onUpdate();
      onFlipEnd?.call();
    }
  }

  /// Disposes the animation controller, notifiers, and releases resources.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isPendingFinalize = false;
    animationController.removeListener(_onAnimationTick);
    animationController.dispose();
    progressNotifier.dispose();
    touchNotifier.dispose();
  }
}
