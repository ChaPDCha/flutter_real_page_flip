import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../controllers/page_flip_state_controller.dart';
import '../models/page_flip_effect_handler.dart';
import '../physics/paper_physics.dart';

/// Professional-grade implementation of [PageFlipEffectHandler].
/// Highlights:
/// - Physics-based haptics: Uses [PaperPhysicsEngine] for realistic paper feel.
/// - Zero-latency audio: Pre-fetched [AudioPlayer] with [AssetSource].
class DefaultPageFlipEffectHandler implements PageFlipEffectHandler {
  /// Initializes the default handler, immediately pre-fetching audio assets.
  DefaultPageFlipEffectHandler({this.screenWidth = 400.0}) {
    _initAudio();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _audioReady = false;

  /// Reference screen width for physics normalization.
  double screenWidth;

  /// Cache of physics engines per page to ensure consistent texture per page.
  final Map<int, PaperPhysicsEngine> _physicsEngines = {};

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('assets/sounds/page_flip.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      _audioReady = true;
    } catch (e) {
      _audioReady = false;
    }
  }

  @override
  void onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
    int? timestampMs,
  }) {
    switch (event) {
      case PageFlipEvent.startHaptic:
        _triggerImpact(HapticImpactType.light);
        break;
      case PageFlipEvent.stopHaptic:
        Vibration.cancel();
        if (pageIndex != null) {
          _physicsEngines[pageIndex]?.reset();
          _evictStaleEngines(pageIndex);
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
            timestampMs: timestampMs,
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
    int? timestampMs,
  }) {
    final engine = _physicsEngines.putIfAbsent(
      pageIndex,
      () => PaperPhysicsEngine(pageNumber: pageIndex),
    );

    final frame = engine.calculate(
      dx: resistance,
      foldAngle: texture,
      screenWidth: screenWidth,
      timestampMs: timestampMs,
    );

    // Execute via Vibration for granular control
    Vibration.hasVibrator().then((has) {
      if (has == true) {
        Vibration.vibrate(
          duration: frame.durationMs,
          amplitude: (frame.amplitude * 255).round().clamp(0, 255),
        );
      } else {
        HapticFeedback.selectionClick();
      }
    });
  }

  /// Evicts physics engines for pages far from [currentPageIndex].
  /// Keeps only pages within ±2 of the current page to prevent memory leaks.
  void _evictStaleEngines(int currentPageIndex) {
    _physicsEngines.removeWhere(
      (key, _) => (key - currentPageIndex).abs() > 2,
    );
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
    _audioPlayer.stop().then((_) {
      _audioPlayer.setVolume(volume);
      _audioPlayer.resume();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _physicsEngines.clear();
  }
}

/// Classifies the general intensity of discrete haptic feedback events.
enum HapticImpactType {
  /// Very light solitary vibration tap.
  light,

  /// Standard solitary vibration tap.
  medium,

  /// Heavy solitary vibration tap.
  heavy
}
