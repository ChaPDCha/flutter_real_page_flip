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

  /// 종이 섬유 질감을 시뮬레이션하는 텍스쳐 햅틱
  /// texture: 0.0~1.0 (텍스쳐 노이즈 강도)
  /// resistance: 0.0~1.0 (페이지 위치 기반 저항감)
  texturedHaptic,

  /// Sound effect trigger for page flip audio.
  sound
}

// Phase increment for paper-texture noise per unit of drag distance.
const double _kNoisePhaseStep = 0.0850509;

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
    _noisePhase = _random.nextDouble() * 1000;
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

  // 난수 생성기 (텍스쳐 노이즈용)
  final math.Random _random = math.Random();

  // Perlin-like noise phase (persists across session).
  double _noisePhase = 0;

  int _currentIndex = 0;
  double _dragProgress = 0;
  Offset _touchPosition = Offset.zero;
  bool _isForward = true;
  bool _isDragging = false;
  bool _blocksContentPointers = false;
  bool _hasPlayedSound = false;
  double _cachedWidth = 1;
  double _lastReleaseVelocity = 0;
  double _smoothedSpeed = 0;
  // 연속 햅틱 타이밍 (프레임 스킵 방지)
  int _hapticFrameCounter = 0;
  /// True while the 1-frame visual transition is pending after a successful flip.
  /// Blocks new drag/tap gestures during this window to prevent re-entrant state.
  bool _isPendingFinalize = false;

  /// Whether a pending finalize transition is in progress.
  /// External callers (e.g. [PageFlipWidget.goToPage]) must check this before
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
        // [Paper Texture Haptic System]
        // 종이를 넘길 때 손가락이 느끼는 마찰 저항을 시뮬레이션
        _hapticFrameCounter++;

        // 프레임 스킵: 60fps 기준 매 프레임마다 진동하면 오버헤드 발생
        // 2프레임마다 1회 (30Hz) 진동으로 최적화
        if (_hapticFrameCounter.isEven) {
          final currentSpeed = delta.abs();
          _smoothedSpeed = (_smoothedSpeed * 0.5) + (currentSpeed * 0.5);

          if (_smoothedSpeed > 0.3) {
            // [1] Continuous Pseudo-noise for Paper Fiber Texture
            // 실제 종이 섬유의 불규칙한 저항감 시뮬레이션
            // _noisePhase를 드래그 거리에 따라 진행시켜 일관된 텍스쳐 생성
            // NOTE: multi-sine sum → square instead of .abs() to avoid
            // derivative discontinuities (cusps) at zero crossings, which
            // produce audible "clicks" in haptic output.
            _noisePhase += _smoothedSpeed * _kNoisePhaseStep;
            final noise1 = math.sin(_noisePhase * 2.7);
            final noise2 = math.sin(_noisePhase * 7.3 + 1.4);
            final noise3 = math.sin(_noisePhase * 13.1 + 2.9);
            // Fractal noise: 다중 주파수 합성으로 자연스러운 질감
            final rawSum =
                (noise1 * 0.5) + (noise2 * 0.3) + (noise3 * 0.2);
            final textureNoise = (rawSum * rawSum).clamp(0.0, 1.0);

            // [2] Non-linear Resistance Model
            // 페이지 시작/끝 근처에서 더 강한 저항 (종이가 붙어있는 느낌)
            // 중간에서는 부드러운 저항
            final edgeDistance = math.min(
              _dragProgress,
              1.0 - _dragProgress,
            );
            // Smoothstep-like curve: 가장자리에서 급격히 저항 증가
            final edgeFactor = 1.0 - (edgeDistance * 2.5).clamp(0.0, 1.0);
            final edgeResistance =
                edgeFactor * edgeFactor * (3 - 2 * edgeFactor);

            // [3] Speed-based Dynamic Intensity
            // 빠를수록 강한 마찰력 (운동 에너지 기반)
            final speedFactor = (_smoothedSpeed / 15.0).clamp(0.2, 1.0);

            // [4] Combine all factors
            final combinedTexture = (textureNoise * 0.6 + 0.4) * speedFactor;
            final combinedResistance = edgeResistance * 0.4 + speedFactor * 0.6;

            // 강도 계산: 기본 강도 + 텍스쳐 변조
            final baseIntensity = (_smoothedSpeed * 6).clamp(30, 180).toInt();
            final textureModulation = (textureNoise * 60).toInt();
            final resistanceBoost = (edgeResistance * 50).toInt();
            final finalIntensity =
                (baseIntensity + textureModulation + resistanceBoost)
                    .clamp(40, 255);

            onEffectTrigger(
              PageFlipEvent.texturedHaptic,
              intensity: finalIntensity,
              texture: combinedTexture,
              resistance: combinedResistance,
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
      }
      // Propagate animation state via notifier — avoids full setState
      // for every animation frame (see PageFlipWidget / ValueListenableBuilder).
      progressNotifier.value = _dragProgress;
      touchNotifier.value = _touchPosition;
    }
  }

  /// Handles the end of a drag, animating the flip to completion or snap-back.
  void onDragEnd(DragEndDetails details, int totalPages) {
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

    animationController
        .animateTo(
          isSuccess ? 1 : 0,
          duration: animationDuration,
          curve: const PaperFlipCurve(),
        )
        .then((_) => _finalizePageChange(isSuccess, totalPages));
  }

  /// Handles cancellation of a drag, snapping the page back.
  void onDragCancel(int totalPages) {
    if (!_isDragging) {
      endPointerCapture();
      onFlipEnd?.call();
      return;
    }
    animationController.value = _dragProgress;
    animationController.animateTo(
      0,
      duration: animationDuration,
      curve: const PaperFlipCurve(),
    );
    _finalizePageChange(false, totalPages);
  }

  /// Triggers a programmatic page flip (e.g. from edge tap or controller).
  void triggerTapFlip({required bool isNext, required int totalPages}) {
    if (_isDragging || animationController.isAnimating || _isPendingFinalize) return;

    if ((isNext && _currentIndex >= totalPages - 1) ||
        (!isNext && _currentIndex <= 0)) {
      return;
    }

    _isForward = isNext;
    _isDragging = true;
    _dragProgress = 0.0;
    _hasPlayedSound = false;

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
      endPointerCapture();
      onEffectTrigger(PageFlipEvent.stopHaptic);
      onUpdate();
      onFlipEnd?.call();
    }
  }

  /// Disposes the animation controller, notifiers, and releases resources.
  void dispose() {
    _isDisposed = true;
    _isPendingFinalize = false;
    animationController.removeListener(_onAnimationTick);
    animationController.dispose();
    progressNotifier.dispose();
    touchNotifier.dispose();
  }
}
