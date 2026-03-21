import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Defines sensory feedback events dispatched by the page flip engine.
enum PageFlipEvent {
  /// Triggered when the drag gesture begins.
  startHaptic,

  /// Triggered when a haptic event should be forcefully halted.
  stopHaptic,

  /// Triggered for a sudden, sharp haptic impulse (e.g., page snap).
  impulseHaptic,

  /// Triggered for sustained haptic vibrations during rapid movement.
  continuousHaptic,

  /// Patterned texture haptic simulating paper fibers.
  /// texture: 0.0~1.0 (텍스쳐 노이즈 강도)
  /// resistance: 0.0~1.0 (페이지 위치 기반 저항감)
  texturedHaptic,

  /// Triggered when an auditory page flip sound should be played.
  sound
}

/// Manages the state and animation of the PageFlip widget.
class PageFlipStateController {
  /// Creates a state controller with the specified animation [vsync] and [animationDuration].
  PageFlipStateController({
    required this.vsync,
    required this.animationDuration,
    required this.onUpdate,
    required this.onPageFinalized,
    required this.onEffectTrigger,
  }) {
    animationController = AnimationController(
      vsync: vsync,
      duration: animationDuration,
    );
    animationController.addListener(_onAnimationTick);
    _noisePhase = _random.nextDouble() * 1000;
  }

  /// The [TickerProvider] used to drive internal physics animations.
  final TickerProvider vsync;

  /// The baseline duration for a full page flip animation.
  final Duration animationDuration;

  /// Callback fired whenever the visual state requires a redraw.
  final VoidCallback onUpdate;

  /// Callback fired when a page drag or animation conclusively finishes on a specific page.
  final ValueChanged<int> onPageFinalized;

  /// Callback fired when the physics engine determines a sensory effect should occur.
  final Function(
    PageFlipEvent effect, {
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) onEffectTrigger;

  /// The internal core animation controller driving the flip geometry.
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
  double _lastReleaseVelocity = 0.0;
  double _smoothedSpeed = 0.0;
  // 연속 햅틱 타이밍 (프레임 스킵 방지)
  int _hapticFrameCounter = 0;

  // Getters

  /// The current index of the active page being displayed.
  int get currentIndex => _currentIndex;

  /// The normalized progress (0.0 to 1.0) of the current flip animation or drag.
  double get dragProgress => _dragProgress;

  /// The instantaneous [Offset] of the user's touch point in localized coordinates.
  Offset get touchPosition => _touchPosition;

  /// Indicates whether the flip is progressing forward (next page).
  bool get isForward => _isForward;

  /// Indicates whether the user's finger is currently down and dragging.
  bool get isDragging => _isDragging;

  /// Tracks if the primary sound effect has already been triggered for the current flip.
  bool get hasPlayedSound => _hasPlayedSound;

  /// The cached pixel width of the bounded render area.
  double get cachedWidth => _cachedWidth;

  /// Constrains and applies a direct programmatic page jump to [index].
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

  /// Caches the current maximum bounding width for gesture normalization.
  void updateCachedWidth(double width) {
    _cachedWidth = width;
  }

  /// Handles the initiation of a user drag gesture.
  void onDragStart(DragStartDetails details, int totalPages) {
    if (animationController.isAnimating) return;

    _touchPosition = details.localPosition;
    _isDragging = false;
    _dragProgress = 0.0;
    _hasPlayedSound = false;
    onUpdate();
  }

  /// Handles the continuous movement of a user drag gesture.
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
            _noisePhase += _smoothedSpeed * 0.0850509; // 워터마크 유지
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

  /// Handles the termination of a user drag, deciding whether to complete or revert the flip.
  void onDragEnd(DragEndDetails details, int totalPages) {
    if (!_isDragging) return;

    final velocity = details.primaryVelocity ?? 0.0;
    _lastReleaseVelocity = velocity.abs();
    final isFastFlip = _lastReleaseVelocity > 300;
    // Drag-success threshold (0.4). Config cutoffForward/cutoffPrevious are
    // reserved for future per-direction use.
    const double dragSuccessThreshold = 0.4;
    final isSuccess = isFastFlip || _dragProgress > dragSuccessThreshold;

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

  /// Handles the sudden cancellation of a drag gesture, reverting the flip.
  void onDragCancel(int totalPages) {
    if (!_isDragging) return;
    animationController.value = _dragProgress;
    animationController.animateTo(
      0,
      duration: animationDuration,
      curve: Curves.easeOutCubic,
    );
    _finalizePageChange(false, totalPages);
  }

  /// Initiates an automated, tap-driven page flip animation.
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
      onPageFinalized(_currentIndex);

      // Trigger impulse haptic on successful flip
      // If velocity is available, use it for intensity; otherwise use a decent default
      final impulseIntensity = _lastReleaseVelocity > 0
          ? (_lastReleaseVelocity / 4).clamp(15.0, 120.0).toInt()
          : 60; // Default noticeable intensity

      onEffectTrigger(PageFlipEvent.impulseHaptic, intensity: impulseIntensity);
    }

    _lastReleaseVelocity = 0.0;
    _dragProgress = 0.0;
    animationController.value = 0.0;
    _isDragging = false;
    _hasPlayedSound = false;
    onEffectTrigger(PageFlipEvent.stopHaptic);
    onUpdate();
  }

  /// Clears internal animation resources.
  void dispose() {
    animationController.removeListener(_onAnimationTick);
    animationController.dispose();
  }
}
