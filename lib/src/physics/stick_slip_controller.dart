/// Types of distinct friction feedback events.
enum StickSlipEventType {
  /// No notable friction change.
  none,

  /// A sudden slip release of built-up static friction energy.
  slipRelease,

  /// A minor fluctuation in dynamic friction.
  microSlip,
}

/// Describes an asynchronous friction event in the page flip engine.
class StickSlipEvent {
  const StickSlipEvent._(this.type, this.intensity);

  /// Creates a [StickSlipEventType.slipRelease] event.
  factory StickSlipEvent.slipRelease({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.slipRelease, intensity);

  /// Creates a [StickSlipEventType.microSlip] event.
  factory StickSlipEvent.microSlip({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.microSlip, intensity);

  /// An empty stick-slip event.
  static const none = StickSlipEvent._(StickSlipEventType.none, 0);

  /// The designated category of friction release.
  final StickSlipEventType type;

  /// The modeled intensity (0.0 to 1.0) of the friction release.
  final double intensity;
}

/// A specialized controller for modeling Stribeck curve dry friction.
class StickSlipController {
  /// Defines parameters mapping velocity changes into sensory feedback events.
  StickSlipController({
    int stationaryThresholdMs = 50,
    double slipVelocityThreshold = 0.02,
  })  : _stationaryThresholdMs = stationaryThresholdMs,
        _slipVelocityThreshold = slipVelocityThreshold;

  int _stationaryThresholdMs;
  double _slipVelocityThreshold;

  /// Time limit before zero-velocity qualifies as strongly adhered stiction.
  set stationaryThresholdMs(int value) => _stationaryThresholdMs = value;

  /// Point at which sliding becomes continuous.
  set slipVelocityThreshold(double value) => _slipVelocityThreshold = value;

  bool _initialized = false;
  bool _wasStationary = true;
  double _lastVelocity = 0;
  double _stickEnergy = 0;
  DateTime _lastMoveTime = DateTime.now();

  /// Ticks the internal simulation according to the instantaneous [velocity].
  StickSlipEvent update(double velocity) {
    final now = DateTime.now();
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

  /// Clears friction constraints and energy accumulators back to baseline.
  void reset() {
    _initialized = false;
    _wasStationary = true;
    _lastVelocity = 0.0;
    _stickEnergy = 0.0;
    _lastMoveTime = DateTime.now();
  }
}
