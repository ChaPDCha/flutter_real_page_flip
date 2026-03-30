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
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
    int? timestampMs,
  }) onEffectTrigger;

  /// The internal core animation controller driving the flip geometry.
  late final AnimationController animationController;

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
    _hapticFrameCounter = 0;
    _smoothedSpeed = 0.0;
    
    // Clear the engine for this page
    onEffectTrigger(PageFlipEvent.startHaptic, pageIndex: _currentIndex);
    
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
      // Ensure pageIndex is passed so DefaultPageFlipEffectHandler can use the Physics engine
      onEffectTrigger(PageFlipEvent.startHaptic, intensity: startIntensity, pageIndex: _currentIndex);
    }

    if (_isDragging) {
      // [Tablet Ergonomic Scale: Non-Linear Acceleration]
      // Wide screens cause drag fatigue if mapped linearly.
      // We dynamically accelerate the gesture across the mid-screen while keeping
      // a 1:1 tactile adhesion at the edges (when dragProgress is near 0 or 1).
      final widthPenalty = ((_cachedWidth - 400) / 400).clamp(0.0, 2.5);
      final progressiveMultiplier = 1.0 + (math.sin(_dragProgress * math.pi) * widthPenalty);

      // Apply signed delta with dynamic ergonomic multiplier
      final progressDelta = ((_isForward ? -delta : delta) * progressiveMultiplier) / _cachedWidth;
      
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
            // [Refactored] Delegate physics to PaperPhysicsEngine
            // 속도와 진행도만 전달, 상세 물리 계산은 EffectHandler의 Engine에서 처리
            final baseIntensity = (_smoothedSpeed * 6).clamp(30, 180).toInt();

            onEffectTrigger(
              PageFlipEvent.texturedHaptic,
              intensity: baseIntensity,
              texture: _dragProgress, // foldAngle
              resistance: delta, // signed delta for bidirectional physics
              pageIndex: _currentIndex, // CRITICAL: Identify which page's physics engine to run!
              timestampMs: details.sourceTimeStamp?.inMilliseconds,
            );
          }
        }

        // Variable Sound Volume: Based on how far we've flipped
        if (_dragProgress > 0.1 && !_hasPlayedSound) {
          final flipSpeed = delta.abs();
          final dynamicVolume = (flipSpeed / 50.0).clamp(0.1, 1.0);
          onEffectTrigger(PageFlipEvent.sound, volume: dynamicVolume, pageIndex: _currentIndex);
          _hasPlayedSound = true;
        }
      }
      onUpdate();
    }
  }

  /// Handles the termination of a user drag, deciding whether to complete or revert the flip.
  void onDragEnd(DragEndDetails details, int totalPages) {
    if (!_isDragging) return;

    final primaryVelocity = details.primaryVelocity ?? 0.0;
    _lastReleaseVelocity = primaryVelocity.abs();

    // Flutter convention:
    // - primaryVelocity < 0 : user swiped Left (forward flip in our engine)
    // - primaryVelocity > 0 : user swiped Right (backward flip in our engine)
    final velocityMatchesDirection =
        _isForward ? primaryVelocity < 0 : primaryVelocity > 0;

    // Make early-release feel natural:
    // - If user releases with a meaningful velocity in the same direction, finish the flip.
    // - Otherwise, fall back to a progress threshold snap.
    const double dragSuccessThreshold = 0.4;
    const double minFlingVelocityPxPerSec = 180.0;

    final shouldFlingFinish =
        velocityMatchesDirection && _lastReleaseVelocity >= minFlingVelocityPxPerSec;
    final isSuccess = shouldFlingFinish || _dragProgress > dragSuccessThreshold;

    // Sync animation value to current drag progress to prevent jumps.
    animationController.value = _dragProgress;

    final target = isSuccess ? 1.0 : 0.0;
    final remaining = (target - _dragProgress).abs().clamp(0.0, 1.0);

    // Dynamic duration based on remaining distance + release velocity.
    // This keeps "early finger lift" smooth, and makes fast swipes finish faster.
    final normalizedSpeed = _cachedWidth <= 0
        ? 0.0
        : (_lastReleaseVelocity / _cachedWidth).clamp(0.0, 6.0); // progress/sec
    final effectiveSpeed = math.max(normalizedSpeed, 1.2); // avoid slow crawl
    final estimatedMs = (remaining / effectiveSpeed * 1000).round();
    final minMs = math.min(160, animationDuration.inMilliseconds);
    final maxMs = animationDuration.inMilliseconds;
    final snapMs = estimatedMs.clamp(minMs, maxMs);

    animationController
        .animateTo(
          target,
          duration: Duration(milliseconds: snapMs),
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
    onEffectTrigger(PageFlipEvent.sound, pageIndex: _currentIndex);
    onEffectTrigger(PageFlipEvent.impulseHaptic, pageIndex: _currentIndex);

    animationController
        .animateTo(
          1,
          duration: animationDuration,
          curve: Curves.easeInOutSine,
        )
        .then((_) => _finalizePageChange(true, totalPages));
  }

  void _finalizePageChange(bool success, int totalPages) {
    // Determine the page that was being interacted with BEFORE any index shift
    final actingPageIndex = _currentIndex;

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

      onEffectTrigger(PageFlipEvent.impulseHaptic, intensity: impulseIntensity, pageIndex: actingPageIndex);
    }

    _lastReleaseVelocity = 0.0;
    _dragProgress = 0.0;
    animationController.value = 0.0;
    _isDragging = false;
    _hasPlayedSound = false;
    onEffectTrigger(PageFlipEvent.stopHaptic, pageIndex: actingPageIndex);
    onUpdate();
  }

  /// Clears internal animation resources.
  void dispose() {
    animationController.removeListener(_onAnimationTick);
    animationController.dispose();
  }
}
