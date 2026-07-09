import 'package:flutter/foundation.dart';

/// Continuous modulation output from the stick-slip controller.
///
/// Unlike the previous discrete-event model (where a slip release emitted a
/// separate `playSlipBurst` that interrupted the normal tick stream), this
/// struct holds smooth 0–1 values that blend into the continuous haptic
/// amplitude via the physics engine — no interruptions, no separate events.
class StickSlipModulation {
  const StickSlipModulation({
    this.amplitudeBoost = 0.0,
    this.sharpnessShift = 0.0,
  });

  /// Amplitude additive boost (0.0–1.0) from accumulated stick energy.
  ///
  /// During a "stick" phase the energy builds. On a "slip" it releases as a
  /// brief amplitude spike rather than a separate native transient.
  final double amplitudeBoost;

  /// Sharpness delta (–0.5 to +0.5) to apply when the stick energy releases.
  ///
  /// Positive = crisper (slip release), negative = softer (re-stick).
  final double sharpnessShift;

  static const zero = StickSlipModulation();
}

/// The type of stick-slip phase detected by [StickSlipController].
///
/// Retained from the discrete model for diagnostics and for the physics
/// engine to decide how to blend the modulation.
enum StickSlipPhase {
  /// No slip activity; normal Coulomb friction.
  none,

  /// Energy is accumulating (finger/paper is stuck).
  sticking,

  /// Energy is releasing (paper slipped past the finger).
  slipping,
}

/// Controller that models stick-slip friction as a continuous amplitude
/// modulation source.
///
/// Real paper does not emit discrete "burst" vibrations when it slips —
/// the stick energy briefly spikes the friction amplitude, then decays back
/// to the kinetic baseline. This controller tracks the stick energy and
/// outputs a smooth [StickSlipModulation] that the physics engine blends
/// into the final haptic amplitude — no preemptive `return` that interrupts
/// the normal tick stream.
class StickSlipController {
  /// Creates a [StickSlipController].
  ///
  /// The [now] parameter allows injecting a custom clock for deterministic
  /// testing. Defaults to [DateTime.now].
  StickSlipController({
    /// Time (ms) the page must be stationary before accumulating stick energy.
    int stationaryThresholdMs = 100,

    /// Velocity threshold below which the page is considered stationary.
    double slipVelocityThreshold = 0.05,

    /// Clock function for time-based calculations. Override for testing.
    DateTime Function() now = DateTime.now,
  })  : _stationaryThresholdMs = stationaryThresholdMs,
        _slipVelocityThreshold = slipVelocityThreshold,
        _now = now,
        _lastUpdateTime = now();

  final DateTime Function() _now;
  int _stationaryThresholdMs;
  double _slipVelocityThreshold;
  DateTime _lastUpdateTime;

  /// Sets the stationary time threshold in milliseconds.
  set stationaryThresholdMs(int value) => _stationaryThresholdMs = value;

  /// Sets the velocity threshold for stationary detection.
  set slipVelocityThreshold(double value) => _slipVelocityThreshold = value;

  // ---------------------------------------------------------------------------
  // Continuous state
  // ---------------------------------------------------------------------------
  bool _initialized = false;
  double _stickEnergy = 0.0; // 0–1, builds while stationary
  double _decayAccumulator = 0.0; // remaining decay after a slip
  bool _wasStationary = true;
  double _lastVelocity = 0.0;
  double _accumulatedStationaryTime = 0.0;
  StickSlipPhase _phase = StickSlipPhase.none;

  /// Updates the controller with the current velocity and returns continuous
  /// modulation values. Call on every drag frame.
  ///
  /// Unlike the old model this never returns separate discrete events.
  /// Stick energy always blends into the returned [StickSlipModulation]
  /// so the caller's tick stream is never interrupted.
  StickSlipModulation update(double velocity) {
    final now = _now();
    final dt = now.difference(_lastUpdateTime).inMilliseconds.toDouble();

    if (!_initialized) {
      _initialized = true;
      _lastUpdateTime = now;
      _lastVelocity = velocity;
      _wasStationary = velocity < _slipVelocityThreshold;
      _accumulatedStationaryTime =
          _wasStationary ? _stationaryThresholdMs.toDouble() : 0;
      _phase = StickSlipPhase.none;
      return StickSlipModulation.zero;
    }

    if (velocity < _slipVelocityThreshold) {
      // ---- Stationary: accumulate stick energy ----
      if (_wasStationary) {
        // Smooth energy build-up capped at 1.0.
        _stickEnergy = (_stickEnergy + dt * 0.0015).clamp(0.0, 1.0);
      } else {
        // Just crossed into stationary territory — accumulate time first.
        _accumulatedStationaryTime += dt;
        if (_accumulatedStationaryTime > _stationaryThresholdMs) {
          _wasStationary = true;
          _stickEnergy = (_accumulatedStationaryTime * 0.0015).clamp(0.0, 1.0);
        }
      }

      if (_stickEnergy > 0.01) {
        _phase = StickSlipPhase.sticking;
      }

      _lastVelocity = velocity;
      _lastUpdateTime = now;
      return StickSlipModulation(
        amplitudeBoost: _stickEnergy * 0.12, // subtle tension build-up
        sharpnessShift: _stickEnergy * -0.15, // softer while stuck
      );
    }

    // ---- Moving ----
    _accumulatedStationaryTime = 0;

    if (_wasStationary && velocity > _slipVelocityThreshold) {
      // ---- Slip release: energy dumps into a brief spike ----
      _wasStationary = false;
      final releaseEnergy = _stickEnergy;
      _stickEnergy = 0.0;

      // Decay the release over ~100ms so the amplitude spike fades smoothly
      // instead of cutting off after one frame.
      _decayAccumulator = releaseEnergy * 0.5;
      _phase = StickSlipPhase.slipping;

      _lastVelocity = velocity;
      _lastUpdateTime = now;

      return StickSlipModulation(
        amplitudeBoost: releaseEnergy * 0.35, // brief spike
        sharpnessShift: releaseEnergy * 0.25, // crisper
      );
    }

    // ---- Steady motion ----
    _wasStationary = false;
    _stickEnergy = 0.0;
    _phase = StickSlipPhase.none;

    // Micro-slip detection for rapid acceleration: adds a subtle sharpness
    // nudge rather than emitting a separate transient.
    final accel = (velocity - _lastVelocity).abs();
    _lastVelocity = velocity;
    _lastUpdateTime = now;

    var amplitudeBoost = 0.0;
    var sharpnessShift = 0.0;

    // Decaying tail from the last slip release.
    if (_decayAccumulator > 0.001) {
      _decayAccumulator *= 0.85; // exponential decay per frame (~60 fps)
      amplitudeBoost += _decayAccumulator * 0.3;
      sharpnessShift += _decayAccumulator * 0.15;
    } else {
      _decayAccumulator = 0.0;
    }

    // Micro-slip: sharpness nudge on rapid acceleration.
    if (accel > 0.22) {
      final microEnergy = (accel * 1.4).clamp(0.0, 0.45);
      amplitudeBoost += microEnergy * 0.15;
      sharpnessShift += microEnergy * 0.20;
    }

    return StickSlipModulation(
      amplitudeBoost: amplitudeBoost.clamp(0.0, 0.5),
      sharpnessShift: sharpnessShift.clamp(-0.3, 0.3),
    );
  }

  /// Resets the controller to its initial state.
  void reset() {
    _initialized = false;
    _stickEnergy = 0.0;
    _decayAccumulator = 0.0;
    _wasStationary = true;
    _lastVelocity = 0.0;
    _accumulatedStationaryTime = 0.0;
    _phase = StickSlipPhase.none;
    _lastUpdateTime = _now();
  }

  // ---------------------------------------------------------------------------
  // Diagnostics / testing support
  // ---------------------------------------------------------------------------

  /// Current stick energy (0–1). Visible for testing.
  @visibleForTesting
  double get stickEnergy => _stickEnergy;

  /// Current stick-slip phase. Visible for testing.
  @visibleForTesting
  StickSlipPhase get phase => _phase;
}
