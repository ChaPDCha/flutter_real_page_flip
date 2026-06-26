import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  DefaultPageFlipEffectHandler({
    this.performanceProfile = DevicePerformanceProfile.high,
    this.hapticTexturePreset = PaperTexturePreset.standard,
    double viewportWidth = 400,
  })  : _textureConfig = PaperTextureConfig.fromPreset(hapticTexturePreset),
        _viewportWidth = viewportWidth {
    _initAudio();
  }

  final DevicePerformanceProfile performanceProfile;
  final PaperTexturePreset hapticTexturePreset;
  final PaperTextureConfig _textureConfig;

  /// The current viewport width used to normalize haptic velocity calculations.
  /// Must be updated when the widget layout changes (default 400 for backward compat).
  double _viewportWidth;

  /// Updates the viewport width so haptic physics match the actual screen size.
  /// Call this from the widget build when the layout is available.
  @override
  set viewportWidth(double width) {
    if (width > 0 && width.isFinite) {
      _viewportWidth = width;
    }
  }

  static const int _audioPoolSize = 3;
  final List<AudioPlayer> _audioPool = List.generate(
    _audioPoolSize,
    (_) => AudioPlayer(),
  );
  int _audioPoolIndex = 0;
  bool _audioReady = false;

  DateTime _lastTextureTick = DateTime.fromMillisecondsSinceEpoch(0);
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
        atLeastOneSuccess = true;
      } on Object {
        try {
          await player.setSource(
            AssetSource('packages/real_page_flip/assets/sounds/page_flip.mp3'),
          );
          await player.setReleaseMode(ReleaseMode.stop);
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
        unawaited(AdvancedHapticEngine.playSystemMedium());
        break;
      case PageFlipEvent.stopHaptic:
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
          // Retain only the current page engine and keep a small window (±2)
          // so rapid sequential flips reuse existing engines without reallocation.
          _physicsEngines.removeWhere(
            (key, _) => (key - pageIndex).abs() > 2,
          );
        }
        break;
      case PageFlipEvent.impulseHaptic:
        unawaited(AdvancedHapticEngine.playThud(intensity: 0.8));
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
          unawaited(AdvancedHapticEngine.playSystemMedium());
        }
        break;
      case PageFlipEvent.sound:
        unawaited(AdvancedHapticEngine.playSystemLight());
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

    final frame = engine.calculate(
      dx: velocityIntensity.toDouble() * 0.1,
      foldAngle: texture,
      screenWidth: _viewportWidth,
    );

    final stickSlip = frame.stickSlipEvent;

    if (stickSlip != null) {
      if (stickSlip.type == StickSlipEventType.slipRelease) {
        unawaited(
          AdvancedHapticEngine.playThud(
            intensity: (stickSlip.intensity * _textureConfig.stiffness * 1.5)
                .clamp(0.0, 1.0),
          ),
        );
        return;
      } else if (stickSlip.type == StickSlipEventType.microSlip) {
        unawaited(
          AdvancedHapticEngine.playTransient(
            intensity:
                (stickSlip.intensity * _textureConfig.friction).clamp(0.0, 1.0),
            sharpness: (_textureConfig.baseSharpness *
                    (1.0 + _textureConfig.roughness * 0.5))
                .clamp(0.0, 1.0),
          ),
        );
        return;
      }
    }

    final normalizedSpeed = (velocityIntensity / 255.0).clamp(0.1, 1.0);
    final baseThrottleMs =
        performanceProfile == DevicePerformanceProfile.low ? 150 : 40;
    final throttleMs =
        (baseThrottleMs / (normalizedSpeed * (1.0 + _textureConfig.roughness)))
            .round()
            .clamp(10, 200);

    final now = DateTime.now();
    if (now.difference(_lastTextureTick).inMilliseconds > throttleMs) {
      _lastTextureTick = now;

      final dynamicIntensity = (_textureConfig.friction * normalizedSpeed +
              _textureConfig.stiffness * resistance * 0.5)
          .clamp(0.0, 1.0);
      final dynamicSharpness = (_textureConfig.baseSharpness *
              (1.0 + _textureConfig.roughness * frame.rawTexture))
          .clamp(0.0, 1.0);

      unawaited(
        AdvancedHapticEngine.playTransient(
          intensity: dynamicIntensity,
          sharpness: dynamicSharpness,
        ),
      );
    }
  }

  void _playSound(double volume) {
    if (!_audioReady) return;

    // Limit max volume and scale dynamically based on gesture speed (velocity/volume)
    final cappedVolume = (volume * 0.4).clamp(0.05, 0.35);

    final player = _audioPool[_audioPoolIndex];
    _audioPoolIndex = (_audioPoolIndex + 1) % _audioPoolSize;
    player.stop().then((_) {
      player.setVolume(cappedVolume);
      player.resume();
    }).catchError((_) {
      // Ignore audio playback errors (e.g. invalid state) to prevent unhandled exceptions.
    });
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
