import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';
import 'package:vibration/vibration.dart';

/// Professional-grade implementation of [PageFlipEffectHandler].
/// Highlights:
/// - Physics-based haptics: Uses [PaperPhysicsEngine] for realistic paper feel.
/// - Zero-latency audio: Pre-fetched [AudioPlayer] pool with [AssetSource].
class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  /// Creates a [DefaultPageFlipEffectHandler] and initialises audio and vibrator.
  DefaultPageFlipEffectHandler({
    this.performanceProfile = DevicePerformanceProfile.high,
  }) {
    _initAudio();
    _initVibrator();
  }

  /// Performance profile to control haptic and audio frequency.
  final DevicePerformanceProfile performanceProfile;

  static const int _audioPoolSize = 3;
  final List<AudioPlayer> _audioPool = List.generate(
    _audioPoolSize,
    (_) => AudioPlayer(),
  );
  int _audioPoolIndex = 0;
  bool _audioReady = false;

  // Cached hardware vibration capabilities to avoid asynchronous platform channels in the hot path.
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;
  bool _initializedVibrator = false;
  DateTime _lastTextureTick = DateTime.fromMillisecondsSinceEpoch(0);

  /// Cache of physics engines per page index for consistent texture.
  final Map<int, PaperPhysicsEngine> _physicsEngines = {};

  Future<void> _initAudio() async {
    var atLeastOneSuccess = false;
    for (final player in _audioPool) {
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        player.audioCache.prefix = '';
        // 1. Try Opus first (More efficient, supported on Android 5.0+, iOS 11+)
        await player.setSource(
          AssetSource('packages/real_page_flip/assets/sounds/page_flip.opus'),
        );
        await player.setReleaseMode(ReleaseMode.stop);
        atLeastOneSuccess = true;
      } on Object {
        try {
          // 2. Fallback to MP3 (Legacy support)
          await player.setSource(
            AssetSource('packages/real_page_flip/assets/sounds/page_flip.mp3'),
          );
          await player.setReleaseMode(ReleaseMode.stop);
          atLeastOneSuccess = true;
        } on Object {
          // Ignore failures on individual players, readiness check is based on whether at least one succeeds.
        }
      }
    }
    _audioReady = atLeastOneSuccess;
  }

  Future<void> _initVibrator() async {
    try {
      final has = await Vibration.hasVibrator();
      _hasVibrator = has;
      if (_hasVibrator) {
        final hasAmp = await Vibration.hasAmplitudeControl();
        _hasAmplitudeControl = hasAmp;
      }
    } on Object {
      _hasVibrator = false;
      _hasAmplitudeControl = false;
    }
    _initializedVibrator = true;
  }

  @override
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {
    switch (event) {
      case PageFlipEvent.startHaptic:
        _triggerStartHaptic();
        break;
      case PageFlipEvent.stopHaptic:
        _cancelHaptic();
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
        }
        break;
      case PageFlipEvent.impulseHaptic:
        _triggerImpulseHaptic();
        break;
      case PageFlipEvent.continuousHaptic:
      case PageFlipEvent.texturedHaptic:
        if (pageIndex != null && texture != null) {
          _handlePhysicsHaptic(
            pageIndex: pageIndex,
            velocityIntensity: intensity ?? 60,
            texture: texture,
            resistance: resistance ?? 0.5,
          );
        } else {
          _triggerStartHaptic();
        }
        break;
      case PageFlipEvent.sound:
        _triggerSoundHaptic();
        _playSound(volume ?? 1.0);
        break;
    }
  }

  void _handlePhysicsHaptic({
    required int pageIndex,
    required int velocityIntensity,
    required double texture,
    required double resistance,
  }) {
    final engine = _physicsEngines.putIfAbsent(
      pageIndex,
      () => PaperPhysicsEngine(pageNumber: pageIndex),
    );

    // Calculate frame (dx is approximated from intensity for now)
    final frame = engine.calculate(
      dx: velocityIntensity.toDouble() * 0.1,
      foldAngle: texture, // map texture param to fold angle for resistance calc
      screenWidth: 400, // standard reference
    );

    final stickSlip = frame.stickSlipEvent;

    // 1. Handle Stick-Slip tactile events with rich vibration signatures
    if (stickSlip != null) {
      if (stickSlip.type == StickSlipEventType.slipRelease) {
        _handleSlipRelease(stickSlip.intensity);
        return;
      } else if (stickSlip.type == StickSlipEventType.microSlip) {
        _handleMicroSlip(stickSlip.intensity);
        return;
      }
    }

    // 2. Handle granular paper texture vibration (the feel of paper fiber ridges)
    // Trigger tick when texture noise crosses standard ridge threshold
    final triggerTextureTick = frame.rawTexture > 0.65;

    if (triggerTextureTick) {
      final now = DateTime.now();
      var throttleMs = 40;
      if (performanceProfile == DevicePerformanceProfile.low) {
        throttleMs = 200;
      } else if (performanceProfile == DevicePerformanceProfile.medium) {
        throttleMs = 80;
      }

      if (now.difference(_lastTextureTick).inMilliseconds > throttleMs) {
        _lastTextureTick = now;
        // Use full physics amplitude range for rich dynamic texture feel
        final amp = (frame.amplitude * 255).round().clamp(10, 255);
        // Crisp duration — shorter than throttle to avoid overlap
        final dur = frame.durationMs.clamp(10, 30);
        _vibrateMotor(durationMs: dur, amplitude: amp);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Haptic primitives
  // ---------------------------------------------------------------------------

  /// iOS path: crisp system haptics via HapticFeedback.
  void _iosHaptic({bool light = false, bool medium = false, bool heavy = false}) {
    try {
      if (heavy) {
        HapticFeedback.heavyImpact();
      } else if (medium) {
        HapticFeedback.mediumImpact();
      } else if (light) {
        HapticFeedback.lightImpact();
      }
    } on Object {
      // HapticFeedback not supported on this platform.
    }
  }

  /// Android motor: single pulse with optional amplitude control.
  void _vibrateMotor({required int durationMs, int amplitude = 128}) {
    if (!_initializedVibrator || !_hasVibrator) return;
    try {
      if (_hasAmplitudeControl) {
        Vibration.vibrate(duration: durationMs, amplitude: amplitude);
      } else {
        Vibration.vibrate(duration: durationMs);
      }
    } on Object {
      // Duration-based vibration requires Android 8+; silently skip on iOS etc.
    }
  }

  /// Android motor: pattern-based multi-pulse sequence.
  /// Pattern format: [off, on, off, on, ...] — first element is initial delay.
  /// Intensities match the pattern length (0 = off, 1-255 = amplitude).
  void _vibratePattern({
    required List<int> pattern,
    List<int>? intensities,
  }) {
    if (!_initializedVibrator || !_hasVibrator) return;
    try {
      if (_hasAmplitudeControl && intensities != null) {
        Vibration.vibrate(pattern: pattern, intensities: intensities);
      } else {
        Vibration.vibrate(pattern: pattern);
      }
    } on Object {
      // Pattern vibration not supported on this platform.
    }
  }

  void _cancelHaptic() {
    if (_initializedVibrator && _hasVibrator) {
      try {
        Vibration.cancel();
      } on Object {
        // Ignore cancel errors on unsupported platforms
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Haptic signatures — each event type has a distinct feel
  // ---------------------------------------------------------------------------

  /// Page-turn start: firm single pulse that signals "drag accepted".
  void _triggerStartHaptic() {
    _iosHaptic(medium: true);
    _vibrateMotor(durationMs: 45, amplitude: 180);
  }

  /// Tap-flip / impulse confirmation: crisp double-tap.
  void _triggerImpulseHaptic() {
    _iosHaptic(light: true);
    _vibratePattern(
      pattern: [0, 30, 12, 28],
      intensities: const [0, 180, 0, 140],
    );
  }

  /// Sound-synchronized haptic: short pulse timed with the audio.
  void _triggerSoundHaptic() {
    _iosHaptic(light: true);
    _vibrateMotor(durationMs: 28, amplitude: 140);
  }

  /// Slip-release: pages slipping past each other.
  /// Intensity (0.0-1.0) from the stick-slip controller's accumulated energy.
  void _handleSlipRelease(double intensity) {
    _iosHaptic(medium: true);
    final onMs = (30 + (intensity * 30)).round().clamp(30, 60);
    final peakAmp = (140 + (intensity * 115)).round().clamp(140, 255);
    _vibratePattern(
      pattern: [0, onMs, 14, (onMs * 0.75).round()],
      intensities: [0, peakAmp, 0, (peakAmp * 0.7).round()],
    );
  }

  /// Micro-slip: tiny acceleration burst.
  /// Intensity (0.0-0.6) from sudden velocity changes.
  void _handleMicroSlip(double intensity) {
    _iosHaptic(light: true);
    _vibrateMotor(
      durationMs: (14 + (intensity * 26)).round().clamp(14, 40),
      amplitude: (80 + (intensity * 130)).round().clamp(80, 210),
    );
  }

  void _playSound(double volume) {
    if (!_audioReady) return;
    final player = _audioPool[_audioPoolIndex];
    _audioPoolIndex = (_audioPoolIndex + 1) % _audioPoolSize;
    player.stop().then((_) {
      player.setVolume(volume);
      player.resume();
    });
  }

  @override
  void dispose() {
    for (final player in _audioPool) {
      player.dispose();
    }
    _physicsEngines.clear();
  }
}

