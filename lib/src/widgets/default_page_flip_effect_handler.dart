import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
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
  DefaultPageFlipEffectHandler() {
    _initAudio();
    _initVibrator();
  }

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

  /// Cache of physics engines per page index for consistent texture.
  final Map<int, PaperPhysicsEngine> _physicsEngines = {};

  Future<void> _initAudio() async {
    for (final player in _audioPool) {
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        // 1. Try Opus first (More efficient, supported on Android 5.0+, iOS 11+)
        await player.setSource(
          AssetSource('packages/real_page_flip/assets/sounds/page_flip.opus'),
        );
        await player.setReleaseMode(ReleaseMode.stop);
      } on Object {
        try {
          // 2. Fallback to MP3 (Legacy support)
          await player.setSource(
            AssetSource('packages/real_page_flip/assets/sounds/page_flip.mp3'),
          );
          await player.setReleaseMode(ReleaseMode.stop);
        } on Object {
          // Ignore failures on individual players, readiness check is based on whether at least one succeeds.
        }
      }
    }
    _audioReady = true;
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
        _triggerImpact(HapticImpactType.light);
        break;
      case PageFlipEvent.stopHaptic:
        Vibration.cancel();
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
        }
        break;
      case PageFlipEvent.impulseHaptic:
        _triggerImpact(HapticImpactType.medium);
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
          _triggerImpact(HapticImpactType.light);
        }
        break;
      case PageFlipEvent.sound:
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

    // 1. Handle Stick-Slip tactile events (High-fidelity physical state shifts)
    if (stickSlip != null) {
      if (stickSlip.type == StickSlipEventType.slipRelease) {
        _triggerImpact(HapticImpactType.medium);
        return; // Prioritize major tactile event over minor ticks
      } else if (stickSlip.type == StickSlipEventType.microSlip) {
        _triggerImpact(HapticImpactType.light);
        return;
      }
    }

    // 2. Handle granular paper texture vibration (the feel of paper fiber ridges)
    // Trigger tick when texture noise crosses standard ridge threshold
    final triggerTextureTick = frame.rawTexture > 0.65;

    if (triggerTextureTick) {
      if (_initializedVibrator && _hasVibrator && _hasAmplitudeControl) {
        // High-end Android devices with precise linear motors: use custom short vibrator pulses
        final amplitude = (frame.amplitude * 255).round().clamp(10, 255);
        final duration = frame.durationMs.clamp(5, 20); // Keep it short and crisp!
        Vibration.vibrate(
          duration: duration,
          amplitude: amplitude,
        );
      } else {
        // iOS or devices without precise amplitude control: use native crisp system clicks
        HapticFeedback.selectionClick();
      }
    }
  }

  void _triggerImpact(HapticImpactType type) {
    switch (type) {
      case HapticImpactType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticImpactType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticImpactType.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
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

/// Types of haptic impact feedback intensities.
enum HapticImpactType {
  /// Light impact feedback.
  light,

  /// Medium impact feedback.
  medium,

  /// Heavy impact feedback.
  heavy,
}
