import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  DefaultPageFlipEffectHandler({
    this.performanceProfile = DevicePerformanceProfile.medium,
    PaperTexturePreset hapticTexturePreset = PaperTexturePreset.standard,
  })  : hapticTexturePreset = hapticTexturePreset,
        _physicsConfig =
            PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset) {
    _initAudio();
  }

  final DevicePerformanceProfile performanceProfile;
  PaperTexturePreset hapticTexturePreset;
  PaperPhysicsConfig _physicsConfig;
  double _viewportWidth = 400;

  @override
  set viewportWidth(double width) {
    if (width.isFinite && width > 0) {
      _viewportWidth = width;
    }
  }

  /// Updates haptic preset state without retaining stale per-page engines.
  void updateConfig({required PaperTexturePreset hapticTexturePreset}) {
    if (this.hapticTexturePreset == hapticTexturePreset) return;
    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart updateConfig: oldPreset=${this.hapticTexturePreset}, newPreset=$hapticTexturePreset, clearedEngines=${_physicsEngines.length}',
      );
    }
    this.hapticTexturePreset = hapticTexturePreset;
    _physicsConfig = PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset);
    _physicsEngines.clear();
  }

  static const int _audioPoolSize = 3;
  static const int _minPaperTickGapMs = 20;

  final List<AudioPlayer> _audioPool = List.generate(
    _audioPoolSize,
    (_) => AudioPlayer(),
  );
  int _audioPoolIndex = 0;
  bool _audioReady = false;
  Source? _audioSource;

  DateTime _lastTextureTick = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPaperTick = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<int, PaperPhysicsEngine> _physicsEngines = {};

  Future<void> _initAudio() async {
    var atLeastOneSuccess = false;
    for (final player in _audioPool) {
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
        player.audioCache.prefix = '';
        await player.setSource(
          AssetSource('packages/real_page_flip/assets/sounds/page_flip.opus'),
        );
        await player.setReleaseMode(ReleaseMode.stop);
        _audioSource ??= AssetSource(
          'packages/real_page_flip/assets/sounds/page_flip.opus',
        );
        atLeastOneSuccess = true;
      } on Object {
        try {
          await player.setSource(
            AssetSource('packages/real_page_flip/assets/sounds/page_flip.mp3'),
          );
          await player.setReleaseMode(ReleaseMode.stop);
          _audioSource ??= AssetSource(
            'packages/real_page_flip/assets/sounds/page_flip.mp3',
          );
          atLeastOneSuccess = true;
        } on Object {
          // Ignore asset load exceptions for secondary formats (mp3 fallback)
        }
      }
    }
    _audioReady = atLeastOneSuccess;
  }

  bool _tryEmitPaperTick({
    required double intensity,
    required double sharpness,
    required int durationMs,
  }) {
    final now = DateTime.now();
    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart _tryEmitPaperTick Attempt: intensity=$intensity, sharpness=$sharpness, durationMs=$durationMs, diffMs=${now.difference(_lastPaperTick).inMilliseconds}',
      );
    }
    if (now.difference(_lastPaperTick).inMilliseconds < _minPaperTickGapMs) {
      return false;
    }
    _lastPaperTick = now;
    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart _tryEmitPaperTick Dispatched: intensity=${intensity.clamp(0.08, 0.55)}, sharpness=${sharpness.clamp(0.15, 0.45)}, durationMs=$durationMs',
      );
    }
    unawaited(
      AdvancedHapticEngine.playTransient(
        intensity: intensity.clamp(0.08, 0.55),
        sharpness: sharpness.clamp(0.15, 0.45),
        durationMs: durationMs,
      ),
    );
    return true;
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
        // Drag texture handles ongoing feedback; a medium pulse here reads as a
        // separate "tap" before the paper scrape begins.
        break;
      case PageFlipEvent.stopHaptic:
        unawaited(AdvancedHapticEngine.cancel());
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
          _physicsEngines.removeWhere(
            (key, _) => (key - pageIndex).abs() > 2,
          );
        }
        break;
      case PageFlipEvent.impulseHaptic:
        // The controller passes intensity 15-120. We map this to 0.4-0.9 for a satisfying settle thud.
        // If intensity is null (e.g., tap flips), default to 90 for a solid landing thud.
        final rawIntensity = (intensity ?? 90) / 120.0;
        final targetIntensity = (rawIntensity * 0.45 + 0.4).clamp(0.4, 0.9);
        unawaited(
          AdvancedHapticEngine.playSettleThud(
            intensity: targetIntensity,
          ),
        );
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
      () => PaperPhysicsEngine(
        pageNumber: pageIndex,
        config: _physicsConfig,
      ),
    );

    final frame = engine.calculate(
      dx: velocityIntensity.toDouble() * 0.1,
      foldAngle: texture,
      screenWidth: _viewportWidth,
    );

    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart Calc: pageIndex=$pageIndex, preset=$hapticTexturePreset, amp=${frame.amplitude}, durationMs=${frame.durationMs}, sharpness=${frame.sharpness}, rawResistance=${frame.rawResistance}, rawTexture=${frame.rawTexture}, rawFriction=${frame.rawFriction}',
      );
    }

    final stickSlip = frame.stickSlipEvent;

    if (stickSlip != null) {
      if (stickSlip.type == StickSlipEventType.slipRelease) {
        // Trigger the multi-pulse native slip burst to give a crisp release feel
        final slipIntensity =
            (stickSlip.intensity * _physicsConfig.frictionScale * 0.65 + 0.15)
                .clamp(0.15, 0.65);
        if (kDebugMode) {
          print(
            '[HAPTIC_DIAGNOSTIC] Dart SlipRelease: intensity=$slipIntensity',
          );
        }
        unawaited(AdvancedHapticEngine.playSlipBurst(intensity: slipIntensity));
        return;
      } else if (stickSlip.type == StickSlipEventType.microSlip) {
        // Trigger a sharper transient tick immediately for micro slip
        final microIntensity =
            (stickSlip.intensity * _physicsConfig.frictionScale * 0.75 + 0.10)
                .clamp(0.10, 0.45);
        if (kDebugMode) {
          print(
            '[HAPTIC_DIAGNOSTIC] Dart MicroSlip: intensity=$microIntensity',
          );
        }
        _lastPaperTick =
            DateTime.now(); // Reset throttle check for immediate feedback
        unawaited(
          AdvancedHapticEngine.playTransient(
            intensity: microIntensity,
            sharpness: 0.38,
            durationMs: 8,
          ),
        );
        return;
      }
    }

    final normalizedSpeed = (velocityIntensity / 255.0).clamp(0.1, 1.0);

    // Smooth continuous throttle mapping: avoids piece-wise discontinuities.
    // Base throttle is tuned so that high speed + high roughness achieves ~16ms,
    // while low speed naturally drops back to >60ms.
    final baseThrottleMs = switch (performanceProfile) {
      DevicePerformanceProfile.low => 80,
      DevicePerformanceProfile.high => 16,
      DevicePerformanceProfile.medium => 24,
    };
    final throttleMs = (baseThrottleMs /
            (normalizedSpeed * (1.0 + _physicsConfig.roughnessScale)))
        .round()
        .clamp(14, 80);

    final now = DateTime.now();
    if (now.difference(_lastTextureTick).inMilliseconds <= throttleMs) {
      return;
    }
    _lastTextureTick = now;

    // Modulate sharpness based on drag velocity: slower drag feels softer/duller, faster feels sharper/crisper
    final speedSharpnessMod = normalizedSpeed * 0.45;
    final dynamicSharpness = (_physicsConfig.baseSharpness * 0.35 +
            _physicsConfig.roughnessScale * frame.rawTexture * 0.2 +
            speedSharpnessMod)
        .clamp(0.15, 0.85);

    _tryEmitPaperTick(
      intensity: frame.amplitude,
      sharpness: dynamicSharpness,
      durationMs: frame.durationMs,
    );
  }

  Future<void> _playOnPlayer(AudioPlayer player, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      await player.resume();
    } on Object {
      // Ignore audio playback errors to prevent unhandled exceptions.
    }
  }

  void _playSound(double volume) {
    if (!_audioReady || _audioSource == null) return;

    final cappedVolume = (volume * 0.4).clamp(0.05, 0.35);

    final player = _audioPool[_audioPoolIndex];
    _audioPoolIndex = (_audioPoolIndex + 1) % _audioPoolSize;

    unawaited(_playOnPlayer(player, cappedVolume));
  }

  @override
  void dispose() {
    _audioReady = false;
    for (final player in _audioPool) {
      player.dispose();
    }
    _physicsEngines.clear();
  }
}
