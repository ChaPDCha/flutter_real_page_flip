/// Types of stick-slip events that can occur during a page drag.
enum StickSlipEventType {
  /// No event; normal motion.
  none,

  /// A slip-release event after accumulating stick energy.
  slipRelease,

  /// A micro-slip from rapid acceleration.
  microSlip,
}

/// Represents a stick-slip event from the [StickSlipController].
class StickSlipEvent {
  const StickSlipEvent._(this.type, this.intensity);

  /// Creates a slip-release event with the given accumulated energy.
  factory StickSlipEvent.slipRelease({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.slipRelease, intensity);

  /// Creates a micro-slip event with the given acceleration intensity.
  factory StickSlipEvent.microSlip({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.microSlip, intensity);

  /// Singleton none event (no slip activity).
  static const none = StickSlipEvent._(StickSlipEventType.none, 0);

  /// The type of stick-slip event.
  final StickSlipEventType type;

  /// The intensity of the event (0.0 to 1.0).
  final double intensity;
}

/// Controller that detects stick-slip events during page dragging.
///
/// Models the physical phenomenon where a stationary object (the page)
/// requires extra force to overcome static friction, then slips suddenly.
class StickSlipController {
  /// Creates a [StickSlipController].
  ///
  /// The [now] parameter allows injecting a custom clock for deterministic
  /// testing. Defaults to [DateTime.now].
  StickSlipController({
    /// Time (ms) the page must be stationary before accumulating stick energy.
    int stationaryThresholdMs = 50,

    /// Velocity threshold below which the page is considered stationary.
    double slipVelocityThreshold = 0.02,

    /// Clock function for time-based calculations. Override for testing.
    DateTime Function() now = DateTime.now,
  })  : _stationaryThresholdMs = stationaryThresholdMs,
        _slipVelocityThreshold = slipVelocityThreshold,
        _now = now,
        _lastMoveTime = now();

  final DateTime Function() _now;
  int _stationaryThresholdMs;
  double _slipVelocityThreshold;

  /// Sets the stationary time threshold in milliseconds.
  set stationaryThresholdMs(int value) => _stationaryThresholdMs = value;

  /// Sets the velocity threshold for stationary detection.
  set slipVelocityThreshold(double value) => _slipVelocityThreshold = value;

  bool _initialized = false;
  bool _wasStationary = true;
  double _lastVelocity = 0;
  double _stickEnergy = 0;
  DateTime _lastMoveTime;

  /// Updates the controller with the current velocity and returns any
  /// stick-slip event. Call on every drag frame.
  StickSlipEvent update(double velocity) {
    final now = _now();
    final dt = now.difference(_lastMoveTime).inMilliseconds;

    if (!_initialized) {
      _initialized = true;
      _lastVelocity = velocity;
      _lastMoveTime = now;
      _wasStationary = velocity < _slipVelocityThreshold;
      return StickSlipEvent.none;
    }

    if (velocity < _slipVelocityThreshold) {
      if (dt > _stationaryThresholdMs) {
        _wasStationary = true;
        _stickEnergy = (_stickEnergy + dt * 0.001).clamp(0.0, 1.0);
      }
      _lastMoveTime = now;
      _lastVelocity = velocity;
      return StickSlipEvent.none;
    }

    if (_wasStationary && velocity > _slipVelocityThreshold) {
      _wasStationary = false;
      final releaseEnergy = _stickEnergy;
      _stickEnergy = 0.0;
      _lastVelocity = velocity;
      _lastMoveTime = now;
      return StickSlipEvent.slipRelease(intensity: releaseEnergy);
    }

    final accel = (velocity - _lastVelocity).abs();
    _lastVelocity = velocity;
    _lastMoveTime = now;

    if (accel > 0.15) {
      return StickSlipEvent.microSlip(intensity: (accel * 2).clamp(0.0, 0.6));
    }

    return StickSlipEvent.none;
  }

  /// Resets the controller to its initial state (clears stick energy).
  void reset() {
    _initialized = false;
    _wasStationary = true;
    _lastVelocity = 0.0;
    _stickEnergy = 0.0;
    _lastMoveTime = _now();
  }
}
