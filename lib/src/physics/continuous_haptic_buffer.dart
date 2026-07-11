import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';

/// Accumulates per-frame haptic samples and flushes them as continuous
/// waveform batches to the native platform.
///
/// Replaces the discrete transient model: instead of calling `AdvancedHapticEngine.playTransient`
/// 60 times/second (each creating a new native player/pattern), samples are
/// collected into a buffer at the frame rate and flushed periodically as an
/// amplitude array. On iOS the array becomes a `CHHapticPattern` parameter
/// curve; on Android it becomes a `VibrationEffect.createWaveform` amplitude
/// array with per-sample timing.
///
/// ## Why this exists
///
/// Discrete transients feel like "tick... tick... tick..." because each is a
/// separate native event with a gap between them. A continuous waveform with
/// smoothly varying amplitude reads as one uninterrupted paper-friction
/// texture — the difference between a strobe light and a dimmer.
class ContinuousHapticBuffer {
  /// Sample interval (ms) for one amplitude value in the native waveform.
  ///
  /// 5 ms = 200 Hz satisfies the Nyquist rate for finger tactile perception
  /// (which tops out around 1 kHz but texture gradients are well below
  /// 100 Hz) while keeping each batch small enough to send over
  /// MethodChannel without jank.
  static const int sampleIntervalMs = 5;

  /// Maximum time (ms) between native batch flushes.
  ///
  /// 40 ms = 25 Hz refresh — fast enough that the human ear/finger cannot
  /// perceive individual batch boundaries, slow enough to keep
  /// MethodChannel traffic at 25 calls/second instead of 60.
  static const int flushIntervalMs = 40;

  /// Minimum interval (ms) enforced between flushes to avoid flooding the
  /// native side with cancels & restarts on Android.
  static const int _minFlushGapMs = 30;

  double _lastIntensity = 0;
  double _lastSharpness = 0.45;
  final List<double> _intensities = [];
  bool _active = false;
  int _lastFlushTime = 0;

  /// Whether a continuous session is active (between [start] and [stop]).
  bool get isActive => _active;

  /// Begins a new continuous haptic session.
  void start() {
    _active = true;
    _intensities.clear();
    _lastIntensity = 0;
    _lastFlushTime = 0;
  }

  /// Adds one amplitude sample (and its sharpness) from the current physics
  /// frame. The latest sharpness represents the batch on the next flush; iOS
  /// applies it to the persistent player's sharpness control.
  void addSample(double intensity, {double sharpness = 0.45}) {
    if (!_active) return;
    _lastIntensity = intensity.clamp(0.0, 1.0);
    _lastSharpness = sharpness.clamp(0.0, 1.0);
    _intensities.add(_lastIntensity);
  }

  /// Whether enough time has passed to warrant a native flush.
  bool shouldFlush(int nowMs) =>
      _active &&
      _intensities.isNotEmpty &&
      (nowMs - _lastFlushTime) >= _minFlushGapMs;

  /// Flushes the accumulated buffer to the native platform as a single
  /// continuous waveform segment and clears the local buffer.
  ///
  /// Call this from the main animation loop after [addSample] when
  /// [shouldFlush] returns true. If the buffer is empty this is a no-op.
  Future<void> flush({required int nowMs}) async {
    if (!_active || _intensities.isEmpty) return;

    final batch = List<double>.from(_intensities);
    final totalDurationMs = (batch.length * sampleIntervalMs).toDouble();
    _intensities.clear();
    _lastFlushTime = nowMs;

    try {
      await AdvancedHapticEngine.playContinuousWaveform(
        intensities: batch,
        totalDurationMs: totalDurationMs,
        sharpness: _lastSharpness,
      );
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[ContinuousHapticBuffer] flush error: $e');
      }
    }
  }

  /// Drops unsent samples and tears down the session immediately.
  ///
  /// Pending samples represent movement that has already ended. Playing them
  /// after pointer-up makes the vibration lag behind the finger.
  Future<void> stop() async {
    if (!_active) return;
    _active = false;

    _intensities.clear();
    _lastIntensity = 0;
    _lastSharpness = 0.45;

    try {
      await AdvancedHapticEngine.stopContinuous();
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[ContinuousHapticBuffer] stop error: $e');
      }
    }
  }

  /// Resets all internal state without sending any native commands.
  /// Useful when the session is abandoned unexpectedly.
  void reset() {
    _active = false;
    _intensities.clear();
    _lastIntensity = 0;
    _lastSharpness = 0.45;
    _lastFlushTime = 0;
  }
}
