enum StickSlipEventType {
  none,
  slipRelease,
  microSlip,
}

class StickSlipEvent {
  const StickSlipEvent._(this.type, this.intensity);

  factory StickSlipEvent.slipRelease({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.slipRelease, intensity);

  factory StickSlipEvent.microSlip({required double intensity}) =>
      StickSlipEvent._(StickSlipEventType.microSlip, intensity);

  static const none = StickSlipEvent._(StickSlipEventType.none, 0);

  final StickSlipEventType type;
  final double intensity;
}

class StickSlipController {
  StickSlipController({
    int stationaryThresholdMs = 50,
    double slipVelocityThreshold = 0.02,
  })  : _stationaryThresholdMs = stationaryThresholdMs,
        _slipVelocityThreshold = slipVelocityThreshold;

  int _stationaryThresholdMs;
  double _slipVelocityThreshold;

  set stationaryThresholdMs(int value) => _stationaryThresholdMs = value;
  set slipVelocityThreshold(double value) => _slipVelocityThreshold = value;

  bool _initialized = false;
  bool _wasStationary = true;
  double _lastVelocity = 0;
  double _stickEnergy = 0;
  DateTime _lastMoveTime = DateTime.now();

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

  void reset() {
    _initialized = false;
    _wasStationary = true;
    _lastVelocity = 0.0;
    _stickEnergy = 0.0;
    _lastMoveTime = DateTime.now();
  }
}
