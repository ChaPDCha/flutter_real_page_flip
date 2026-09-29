import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';
import 'package:real_page_flip/src/models/haptic_strength.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/page_flip_sound_player.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/models/perceptual_haptic_gain.dart';
import 'package:real_page_flip/src/physics/continuous_haptic_buffer.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_sound.dart';

export 'package:real_page_flip/src/widgets/default_page_flip_sound.dart'
    show cappedFlipSoundVolume;

@visibleForTesting
({double amplitude, double sharpness, int samplesPerGrain})
    shapePaperHapticOutput({
  required PaperTexturePreset preset,
  required double rawAmplitude,
  required double rawSharpness,
  required double speedFactor,
  double perceptualGain = 1.0,
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
  final amplitude = PerceptualHapticGain.apply(
    (amplitudeBand * materialVariation).clamp(0.0, profile.maxAmplitude),
    gain: perceptualGain,
  );
  final sharpness =
      (profile.sharpness * 0.8 + rawSharpness.clamp(0.0, 1.0) * 0.2)
          .clamp(0.0, 1.0);

  return (
    amplitude: amplitude,
    sharpness: sharpness,
    samplesPerGrain: profile.samplesPerGrain,
  );
}

/// Uses slower, sparser feedback for gentle drags and denser feedback for
/// fast turns. This is the tactile speed cue on motors without amplitude
/// control, where a continuous waveform would feel like an intrusive buzz.
@visibleForTesting
int discretePaperTickGapMs(double speedFactor) {
  final speed = speedFactor.clamp(0.0, 1.0);
  final curve = speed * speed * (3 - 2 * speed);
  return (84 - 48 * curve).round();
}

@visibleForTesting
double paperSettleIntensity({
  required PaperTexturePreset preset,
  required int controllerIntensity,
  double perceptualGain = 1.0,
}) {
  if (!preset.hapticsEnabled) return 0;
  final level = preset.hapticLevel / 4.0;
  final gesture = (controllerIntensity / 120.0).clamp(0.0, 1.0);
  // Soft landing tick only — scrape carries the tactile story; settle is a
  // quiet "page arrived" cue that must stay well below drag texture peaks.
  //
  // The band tracks the authored texture bands: the old 0.06–0.22 window was
  // set when drag peaked at 0.22, so settle sat at parity with the scrape and
  // had to be held down. Against the current bands it is the single most
  // noticed event in the flip and was landing under 0.26 on iOS.
  final raw = (0.16 + level * 0.18 + gesture * 0.10).clamp(0.14, 0.44);
  return PerceptualHapticGain.apply(raw, gain: perceptualGain);
}

@visibleForTesting
({double intensity, double sharpness, int durationMs}) paperDetentOutput(
  PaperTexturePreset preset, {
  double perceptualGain = 1.0,
}) {
  if (!preset.hapticsEnabled) {
    return (intensity: 0, sharpness: 0, durationMs: 0);
  }
  final profile = preset.hapticOutputProfile;
  return (
    intensity: PerceptualHapticGain.apply(
      0.16 + preset.hapticLevel * 0.075,
      gain: perceptualGain,
    ),
    sharpness: profile.sharpness,
    durationMs: 6 + preset.hapticLevel * 3,
  );
}

class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  DefaultPageFlipEffectHandler({
    PaperTexturePreset hapticTexturePreset = PaperTexturePreset.standard,
    this.hapticQuality = HapticQuality.adaptive,
    this.hapticStrength = HapticStrength.medium,
    TargetPlatform? platform,
    PageFlipSoundPlayer? soundPlayer,
  })  : hapticTexturePreset = hapticTexturePreset,
        _soundPlayer = soundPlayer ?? DefaultPageFlipSound(),
        _ownsSoundPlayer = soundPlayer == null,
        _platform = platform ?? defaultTargetPlatform,
        _resolvedHapticQuality = hapticQuality == HapticQuality.adaptive
            ? HapticQuality.basic
            : hapticQuality,
        _physicsConfig =
            PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset) {
    _refreshPerceptualGain();
    _resolveHapticQuality();
  }

  /// Plays the turn sound. The default loads lazily on first use, so a
  /// handler whose sound is disabled never allocates an audio player.
  final PageFlipSoundPlayer _soundPlayer;

  /// Whether [_soundPlayer] was created here (and must be disposed here).
  final bool _ownsSoundPlayer;

  /// The sound player this handler routes [PageFlipEvent.sound] to.
  PageFlipSoundPlayer get soundPlayer => _soundPlayer;

  PaperTexturePreset hapticTexturePreset;
  HapticQuality hapticQuality;
  HapticStrength hapticStrength;
  final TargetPlatform _platform;
  HapticQuality _resolvedHapticQuality;
  double _perceptualGain = 1;
  PaperPhysicsConfig _physicsConfig;
  double _viewportWidth = 400;

  @visibleForTesting
  double get debugPerceptualGain => _perceptualGain;

  @visibleForTesting
  HapticQuality get debugResolvedHapticQuality => _resolvedHapticQuality;

  // ---------------------------------------------------------------------------
  // Continuous haptic buffer — premium path only.
  // ---------------------------------------------------------------------------
  final ContinuousHapticBuffer _continuousBuffer = ContinuousHapticBuffer();

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
    HapticStrength? hapticStrength,
  }) {
    final nextStrength = hapticStrength ?? this.hapticStrength;
    if (this.hapticTexturePreset == hapticTexturePreset &&
        this.hapticQuality == hapticQuality &&
        this.hapticStrength == nextStrength) {
      return;
    }
    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart updateConfig: oldPreset=${this.hapticTexturePreset}, newPreset=$hapticTexturePreset, clearedEngines=${_physicsEngines.length}',
      );
    }
    this.hapticTexturePreset = hapticTexturePreset;
    this.hapticQuality = hapticQuality;
    this.hapticStrength = nextStrength;
    _physicsConfig = PaperPhysicsConfig.fromTexturePreset(hapticTexturePreset);
    _physicsEngines.clear();
    if (!hapticTexturePreset.hapticsEnabled) {
      unawaited(_continuousBuffer.stop());
    }
    _refreshPerceptualGain();
    _resolveHapticQuality();
  }

  void _refreshPerceptualGain() {
    _perceptualGain = PerceptualHapticGain.combined(
      resolvedQuality: _resolvedHapticQuality,
      platform: _platform,
      strength: hapticStrength,
    );
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
    _refreshPerceptualGain();
    if (resolved == HapticQuality.basic) {
      unawaited(_continuousBuffer.stop());
    }
  }

  final Map<int, PaperPhysicsEngine> _physicsEngines = {};

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
        // Soft landing tick for every quality route — never the old settle
        // thud, which competed with paper scrape and read as a spare buzz.
        final targetIntensity = _resolvedHapticQuality == HapticQuality.basic
            ? PerceptualHapticGain.apply(0.40, gain: _perceptualGain)
            : paperSettleIntensity(
                preset: hapticTexturePreset,
                controllerIntensity: intensity ?? 90,
                perceptualGain: _perceptualGain,
              );
        unawaited(
          AdvancedHapticEngine.playTransient(
            intensity: targetIntensity,
            sharpness: 0.22,
            durationMs: 8,
          ),
        );
        break;
      case PageFlipEvent.continuousHaptic:
      case PageFlipEvent.texturedHaptic:
        // Basic and standard devices use sparse discrete paper ticks; premium
        // devices use the continuous waveform. This keeps legacy iPhones
        // tactile without reintroducing a continuous buzz.
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
            ? (
                intensity: PerceptualHapticGain.apply(
                  0.34,
                  gain: _perceptualGain,
                ),
                sharpness: 0.5,
                durationMs: 8,
              )
            : paperDetentOutput(
                hapticTexturePreset,
                perceptualGain: _perceptualGain,
              );
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
      perceptualGain: _perceptualGain,
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
        speedFactor: speedFactor,
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
    required double speedFactor,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastDiscreteTickMs < discretePaperTickGapMs(speedFactor)) {
      return;
    }
    _lastDiscreteTickMs = nowMs;
    unawaited(
      AdvancedHapticEngine.playTransient(
        // Upper bound is the shared soft ceiling, not 0.55: `amplitude` has
        // already passed through PerceptualHapticGain.apply, so a lower cap
        // here re-flattened heavy back onto medium for every texture above
        // `standard` on the discrete (non-premium) route.
        intensity: amplitude.clamp(0.05, PerceptualHapticGain.amplitudeCeiling),
        sharpness: sharpness.clamp(0.2, 0.95),
        durationMs: 10,
      ),
    );
  }

  void _playSound(double volume) {
    try {
      final result = _soundPlayer.play(volume: volume);
      if (result is Future<void>) {
        unawaited(result.catchError((Object _) {}));
      }
    } on Object {
      // Sound is optional: a failing player must never affect navigation.
    }
  }

  @override
  void dispose() {
    if (_ownsSoundPlayer) _soundPlayer.dispose();
    _physicsEngines.clear();
    // `reset()` only clears Dart state. A premium iOS drag owns a looped
    // CHHaptic player, so disposal must cross the platform boundary before
    // abandoning the buffer or the native session can outlive this handler.
    unawaited(_continuousBuffer.stop());
  }
}
