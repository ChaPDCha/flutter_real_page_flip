import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/physics/continuous_haptic_buffer.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';

/// Final player-volume guard shared by drag and tap flips.
@visibleForTesting
double cappedFlipSoundVolume(double requestedVolume) {
  final safeVolume = requestedVolume.isFinite ? requestedVolume : 0.0;
  return (safeVolume.clamp(0.0, 1.0) * 0.4).clamp(0.04, 0.22);
}

@visibleForTesting
({double amplitude, double sharpness, int samplesPerGrain})
    shapePaperHapticOutput({
  required PaperTexturePreset preset,
  required double rawAmplitude,
  required double rawSharpness,
  required double speedFactor,
}) {
  final profile = preset.hapticOutputProfile;
  if (!preset.hapticsEnabled) {
    return (amplitude: 0, sharpness: 0, samplesPerGrain: 0);
  }

  final speed = speedFactor.clamp(0.0, 1.0);
  final speedCurve = speed * speed * (3 - 2 * speed);
  final amplitudeBand = profile.minAmplitude +
      (profile.maxAmplitude - profile.minAmplitude) * speedCurve;
  final materialVariation = 0.9 + rawAmplitude.clamp(0.0, 1.0) * 0.1;
  final amplitude =
      (amplitudeBand * materialVariation).clamp(0.0, profile.maxAmplitude);
  final sharpness =
      (profile.sharpness * 0.8 + rawSharpness.clamp(0.0, 1.0) * 0.2)
          .clamp(0.0, 1.0);

  return (
    amplitude: amplitude,
    sharpness: sharpness,
    samplesPerGrain: profile.samplesPerGrain,
  );
}

@visibleForTesting
double paperSettleIntensity({
  required PaperTexturePreset preset,
  required int controllerIntensity,
}) {
  if (!preset.hapticsEnabled) return 0;
  final level = preset.hapticLevel / 4.0;
  final gesture = (controllerIntensity / 120.0).clamp(0.0, 1.0);
  return (0.12 + level * 0.48 + gesture * 0.22).clamp(0.0, 0.82);
}

@visibleForTesting
({double intensity, double sharpness, int durationMs}) paperDetentOutput(
  PaperTexturePreset preset,
) {
  if (!preset.hapticsEnabled) {
    return (intensity: 0, sharpness: 0, durationMs: 0);
  }
  final profile = preset.hapticOutputProfile;
  return (
    intensity: 0.12 + preset.hapticLevel * 0.08,
    sharpness: profile.sharpness,
    durationMs: 6 + preset.hapticLevel * 3,
  );
}

class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  DefaultPageFlipEffectHandler({
    this.performanceProfile = DevicePerformanceProfile.medium,
    PaperTexturePreset hapticTexturePreset = PaperTexturePreset.standard,
    this.hapticQuality = HapticQuality.adaptive,
  })  : hapticTexturePreset = hapticTexturePreset,
        _resolvedHapticQuality = hapticQuality == HapticQuality.adaptive
            ? HapticQuality.basic
            : hapticQuality,
        _physicsConfig =
            PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset) {
    _initAudio();
    _resolveHapticQuality();
  }

  final DevicePerformanceProfile performanceProfile;
  PaperTexturePreset hapticTexturePreset;
  HapticQuality hapticQuality;
  HapticQuality _resolvedHapticQuality;
  PaperPhysicsConfig _physicsConfig;
  double _viewportWidth = 400;

  // ---------------------------------------------------------------------------
  // Continuous haptic buffer — premium path only.
  // ---------------------------------------------------------------------------
  final ContinuousHapticBuffer _continuousBuffer = ContinuousHapticBuffer();

  /// Throttle for [HapticQuality.standard] discrete drag ticks.
  static const int _discreteTickGapMs = 36;
  int _lastDiscreteTickMs = 0;

  @override
  set viewportWidth(double width) {
    if (width.isFinite && width > 0) {
      _viewportWidth = width;
    }
  }

  /// Updates haptic preset state without retaining stale per-page engines.
  void updateConfig({
    required PaperTexturePreset hapticTexturePreset,
    required HapticQuality hapticQuality,
  }) {
    if (this.hapticTexturePreset == hapticTexturePreset &&
        this.hapticQuality == hapticQuality) {
      return;
    }
    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart updateConfig: oldPreset=${this.hapticTexturePreset}, newPreset=$hapticTexturePreset, clearedEngines=${_physicsEngines.length}',
      );
    }
    this.hapticTexturePreset = hapticTexturePreset;
    this.hapticQuality = hapticQuality;
    _physicsConfig = PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset);
    _physicsEngines.clear();
    if (!hapticTexturePreset.hapticsEnabled) {
      unawaited(_continuousBuffer.stop());
    }
    _resolveHapticQuality();
  }

  Future<void> _resolveHapticQuality() async {
    final capabilities = await AdvancedHapticEngine.getCapabilities();
    final resolved = capabilities.resolve(hapticQuality);
    if (resolved != _resolvedHapticQuality && kDebugMode) {
      debugPrint(
        '[HAPTIC_DIAGNOSTIC] resolved quality=$resolved '
        'amplitude=${capabilities.hasAmplitudeControl} '
        'advanced=${capabilities.hasAdvancedHaptics}',
      );
    }
    _resolvedHapticQuality = resolved;
    if (resolved == HapticQuality.basic) {
      unawaited(_continuousBuffer.stop());
    }
  }

  static const int _audioPoolSize = 3;

  final List<AudioPlayer> _audioPool = List.generate(
    _audioPoolSize,
    (_) => AudioPlayer(),
  );
  int _audioPoolIndex = 0;
  bool _audioReady = false;
  Source? _audioSource;

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

  @override
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {
    final isHaptic = switch (event) {
      PageFlipEvent.startHaptic ||
      PageFlipEvent.stopHaptic ||
      PageFlipEvent.impulseHaptic ||
      PageFlipEvent.continuousHaptic ||
      PageFlipEvent.texturedHaptic ||
      PageFlipEvent.detentHaptic =>
        true,
      PageFlipEvent.sound => false,
    };
    if (isHaptic && !hapticTexturePreset.hapticsEnabled) {
      if (_continuousBuffer.isActive) {
        unawaited(_continuousBuffer.stop());
      }
      return Future<void>.value();
    }

    switch (event) {
      case PageFlipEvent.startHaptic:
        // Drag texture handles ongoing feedback; a medium pulse here reads as a
        // separate "tap" before the paper scrape begins.
        break;
      case PageFlipEvent.stopHaptic:
        // Stop the continuous waveform session cleanly.
        unawaited(_continuousBuffer.stop());
        _lastDiscreteTickMs = 0;
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
          _physicsEngines.removeWhere(
            (key, _) => (key - pageIndex).abs() > 2,
          );
        }
        break;
      case PageFlipEvent.impulseHaptic:
        final targetIntensity = _resolvedHapticQuality == HapticQuality.basic
            ? 0.35
            : paperSettleIntensity(
                preset: hapticTexturePreset,
                controllerIntensity: intensity ?? 90,
              );
        unawaited(
          AdvancedHapticEngine.playSettleThud(
            intensity: targetIntensity,
          ),
        );
        break;
      case PageFlipEvent.continuousHaptic:
      case PageFlipEvent.texturedHaptic:
        // basic: no drag texture. standard: discrete ticks. premium: continuous.
        if (_resolvedHapticQuality == HapticQuality.basic) break;
        if (pageIndex != null && texture != null) {
          _handlePhysicsHaptic(
            pageIndex: pageIndex,
            velocityIntensity: intensity ?? 60,
            // `texture` from the older controller is a multi-sine noise
            // value consumed for backward compatibility. The physics
            // engine now uses ONLY its internal Perlin noise. The value
            // is still accepted but interpreted as fold-angle hint.
            texture: texture,
            resistance: resistance ?? 0.5,
          );
        }
        break;
      case PageFlipEvent.detentHaptic:
        // A single crisp, low-intensity micro-tick — deliberately much
        // smaller than the settle thud so it reads as a subtle "this will
        // commit" confirmation layered on TOP of the ongoing friction
        // texture, not a second event competing with it. Reuses the
        // existing discrete playTransient path (no new native surface).
        final detent = _resolvedHapticQuality == HapticQuality.basic
            ? (intensity: 0.18, sharpness: 0.5, durationMs: 8)
            : paperDetentOutput(hapticTexturePreset);
        unawaited(
          AdvancedHapticEngine.playTransient(
            intensity: detent.intensity,
            sharpness: detent.sharpness,
            durationMs: detent.durationMs,
          ),
        );
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

    // Use the controller's `texture` value as fold progress (0–1) rather
    // than noise. The physics engine now generates its own Perlin texture
    // and keeps `foldAngle` as a geometric input.
    final foldProgress = texture.clamp(0.0, 1.0);

    final frame = engine.calculate(
      dx: velocityIntensity.toDouble() * 0.1,
      foldAngle: foldProgress,
      screenWidth: _viewportWidth,
    );
    final speedFactor = resistance.clamp(0.0, 1.0);
    final output = shapePaperHapticOutput(
      preset: hapticTexturePreset,
      rawAmplitude: frame.amplitude,
      rawSharpness: frame.sharpness,
      speedFactor: speedFactor,
    );

    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart Calc: pageIndex=$pageIndex, preset=$hapticTexturePreset, level=${hapticTexturePreset.hapticLevel}, quality=$_resolvedHapticQuality, rawAmp=${frame.amplitude}, outputAmp=${output.amplitude}, speedFactor=$speedFactor, sharpness=${output.sharpness}, grainMs=${output.samplesPerGrain * ContinuousHapticBuffer.sampleIntervalMs}, durationMs=${frame.durationMs}, slipBoost=${frame.stickSlipModulation?.amplitudeBoost.toStringAsFixed(3) ?? 'none'}',
      );
    }

    if (output.amplitude <= 0 || output.samplesPerGrain <= 0) {
      return;
    }

    // Mid-tier motors: discrete ticks only — continuous waveform buzzes.
    if (_resolvedHapticQuality != HapticQuality.premium) {
      _emitDiscreteDragTick(
        amplitude: output.amplitude,
        sharpness: output.sharpness,
      );
      return;
    }

    // ---- Premium continuous waveform pipeline ----
    //
    // The old model:
    //   1. Check stick-slip → emit playSlipBurst → return (INTERRUPTS stream)
    //   2. Check throttle → skip if too soon
    //   3. Call _tryEmitPaperTick → playTransient
    //
    // New model:
    //   1. Feed every frame into the continuous buffer
    //   2. Buffer flushes every ~40ms as a native waveform segment
    //   3. Stick-slip energy is ALREADY blended into frame.amplitude
    //      by PaperPhysicsEngine — no separate event emission needed.

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Start continuous session on the first frame.
    if (!_continuousBuffer.isActive) {
      _continuousBuffer.start();
    }

    // Add the current frame's amplitude + sharpness to the buffer. Sharpness
    // rises with velocity/texture so fast flicks feel crisp and slow drags soft.
    for (var i = 0; i < output.samplesPerGrain; i++) {
      final tailScale = 1 - i * 0.08;
      _continuousBuffer.addSample(
        output.amplitude * tailScale,
        sharpness: output.sharpness,
      );
    }

    // Flush periodically (every ~40ms) to the native platform.
    if (_continuousBuffer.shouldFlush(nowMs)) {
      unawaited(_continuousBuffer.flush(nowMs: nowMs));
    }
  }

  void _emitDiscreteDragTick({
    required double amplitude,
    required double sharpness,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastDiscreteTickMs < _discreteTickGapMs) {
      return;
    }
    _lastDiscreteTickMs = nowMs;
    unawaited(
      AdvancedHapticEngine.playTransient(
        intensity: amplitude.clamp(0.05, 0.55),
        sharpness: sharpness.clamp(0.2, 0.95),
        durationMs: 10,
      ),
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

    final cappedVolume = cappedFlipSoundVolume(volume);

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
    _continuousBuffer.reset();
  }
}
