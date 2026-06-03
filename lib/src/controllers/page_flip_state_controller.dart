import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  /// The underlying animation controller driving flip transitions.
  late final AnimationController animationController;

  // 난수 생성기 (텍스쳐 노이즈용)
  final math.Random _random = math.Random();

  // Perlin-like 노이즈 위상 (세션당 지속)
  late double _noisePhase;

  int _currentIndex = 0;
  double _dragProgress = 0;
  Offset _touchPosition = Offset.zero;
  bool _isForward = true;
  bool _isDragging = false;
  bool _hasPlayedSound = false;
  double _cachedWidth = 1;
  double _lastReleaseVelocity = 0;
  double _smoothedSpeed = 0;
  // 연속 햅틱 타이밍 (프레임 스킵 방지)
  int _hapticFrameCounter = 0;

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
    onUpdate();
  }

  /// Updates the cached widget width for normalising drag deltas.
  void updateCachedWidth(double width) {
    _cachedWidth = width;
  }

  /// Handles the start of a drag gesture for page flipping.
  void onDragStart(DragStartDetails details, int totalPages) {
    if (animationController.isAnimating) return;

    onFlipStart?.call();
    _touchPosition = details.localPosition;
    _isDragging = false;
    _dragProgress = 0.0;
    _hasPlayedSound = false;
    onUpdate();
  }

  /// Handles a drag update, updating progress and triggering textured haptics.
  void onDragUpdate(DragUpdateDetails details, int totalPages) {
    if (animationController.isAnimating) return;

    _touchPosition = details.localPosition;
    final delta = details.primaryDelta ?? 0.0;

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
        if (_hapticFrameCounter % 2 == 0) {
          final currentSpeed = delta.abs();
          _smoothedSpeed = (_smoothedSpeed * 0.5) + (currentSpeed * 0.5);

          if (_smoothedSpeed > 0.3) {
            // [1] Simplex-like Noise for Paper Fiber Texture
            // 실제 종이 섬유의 불규칙한 저항감 시뮬레이션
            // _noisePhase를 드래그 거리에 따라 진행시켜 일관된 텍스쳐 생성
            _noisePhase += _smoothedSpeed * _kNoisePhaseStep;
            final noise1 = math.sin(_noisePhase * 2.7);
            final noise2 = math.sin(_noisePhase * 7.3 + 1.4);
            final noise3 = math.sin(_noisePhase * 13.1 + 2.9);
            // Fractal noise: 다중 주파수 합성으로 자연스러운 질감
            final textureNoise =
                ((noise1 * 0.5) + (noise2 * 0.3) + (noise3 * 0.2)).abs();

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
      onUpdate();
    }
  }

  /// Handles the end of a drag, animating the flip to completion or snap-back.
  void onDragEnd(DragEndDetails details, int totalPages) {
    if (!_isDragging) {
      onFlipEnd?.call();
      return;
    }

    final velocity = details.primaryVelocity ?? 0.0;
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
          curve: Curves.easeOutCubic,
        )
        .then((_) => _finalizePageChange(isSuccess, totalPages));
  }

  /// Handles cancellation of a drag, snapping the page back.
  void onDragCancel(int totalPages) {
    if (!_isDragging) {
      onFlipEnd?.call();
      return;
    }
    animationController.value = _dragProgress;
    animationController.animateTo(
      0,
      duration: animationDuration,
      curve: Curves.easeOutCubic,
    );
    _finalizePageChange(false, totalPages);
  }

  /// Triggers a programmatic page flip (e.g. from edge tap or controller).
  void triggerTapFlip(bool isNext, int totalPages) {
    if (_isDragging || animationController.isAnimating) return;

    if ((isNext && _currentIndex >= totalPages - 1) ||
        (!isNext && _currentIndex <= 0)) {
      return;
    }

    _isForward = isNext;
    _isDragging = true;
    _dragProgress = 0.0;
    _hasPlayedSound = false;

    onFlipStart?.call();

    animationController.stop();
    animationController.value = 0.0;
    onEffectTrigger(PageFlipEvent.sound);
    onEffectTrigger(PageFlipEvent.impulseHaptic);

    animationController
        .animateTo(
          1,
          duration: animationDuration,
          curve: Curves.easeInOutSine,
        )
        .then((_) => _finalizePageChange(true, totalPages));
  }

  void _finalizePageChange(bool success, int totalPages) {
    if (success) {
      if (_isForward) {
        _currentIndex++;
      } else {
        _currentIndex--;
      }

      // CRITICAL FIX: Reset drag state BEFORE calling onPageFinalized/onUpdate.
      // This ensures the very next frame renders the NEW page as `keyedCurrentPage`
      // at progress=0 (idle state), preventing the 1-frame visual discontinuity
      // where the old flip layers (with stale snapshot/opacity) would briefly flash
      // before being replaced by the new idle page.
      _dragProgress = 0.0;
      animationController.value = 0.0;
      _isDragging = false;
      _hasPlayedSound = false;
      _lastReleaseVelocity = 0.0;

      onEffectTrigger(PageFlipEvent.stopHaptic);

      // Trigger impulse haptic on successful flip
      final impulseIntensity = _lastReleaseVelocity > 0
          ? (_lastReleaseVelocity / 4).clamp(15.0, 120.0).toInt()
          : 60;
      onEffectTrigger(PageFlipEvent.impulseHaptic, intensity: impulseIntensity);

      // Now notify: the page index is updated, drag state is clean,
      // so the next build will render the new page cleanly in idle mode.
      onPageFinalized(_currentIndex);
      onUpdate();
      onFlipEnd?.call();
    } else {
      // Cancelled flip: snap back
      _lastReleaseVelocity = 0.0;
      _dragProgress = 0.0;
      animationController.value = 0.0;
      _isDragging = false;
      _hasPlayedSound = false;
      onEffectTrigger(PageFlipEvent.stopHaptic);
      onUpdate();
      onFlipEnd?.call();
    }
  }

  /// Disposes the animation controller and releases resources.
  void dispose() {
    animationController.removeListener(_onAnimationTick);
    animationController.dispose();
  }
}
