import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/physics/continuous_haptic_buffer.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';

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

  // ---------------------------------------------------------------------------
  // Continuous haptic buffer — replaces the discrete transient pipeline.
  // ---------------------------------------------------------------------------
  final ContinuousHapticBuffer _continuousBuffer = ContinuousHapticBuffer();

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
    switch (event) {
      case PageFlipEvent.startHaptic:
        // Drag texture handles ongoing feedback; a medium pulse here reads as a
        // separate "tap" before the paper scrape begins.
        break;
      case PageFlipEvent.stopHaptic:
        // Stop the continuous waveform session cleanly.
        unawaited(_continuousBuffer.stop());
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
          _physicsEngines.removeWhere(
            (key, _) => (key - pageIndex).abs() > 2,
          );
        }
        break;
      case PageFlipEvent.impulseHaptic:
        // The controller passes intensity 15-120. We map this to 0.4-0.9 for a
        // satisfying settle thud. If intensity is null (e.g., tap flips),
        // default to 90 for a solid landing thud.
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
        unawaited(
          AdvancedHapticEngine.playTransient(
            intensity: 0.32,
            sharpness: 0.75,
            durationMs: 10,
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

    if (kDebugMode) {
      print(
        '[HAPTIC_DIAGNOSTIC] Dart Calc: pageIndex=$pageIndex, preset=$hapticTexturePreset, amp=${frame.amplitude}, sharpness=${frame.sharpness}, durationMs=${frame.durationMs}, slipBoost=${frame.stickSlipModulation?.amplitudeBoost.toStringAsFixed(3) ?? 'none'}',
      );
    }

    // ---- Continuous waveform pipeline (replaces discrete transients) ----
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
    _continuousBuffer.addSample(frame.amplitude, sharpness: frame.sharpness);

    // Flush periodically (every ~40ms) to the native platform.
    if (_continuousBuffer.shouldFlush(nowMs)) {
      unawaited(_continuousBuffer.flush(nowMs: nowMs));
    }
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
    _continuousBuffer.reset();
  }
}
