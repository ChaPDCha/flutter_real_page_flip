/// Types of distinct friction feedback events.
enum StickSlipEventType {
  /// No notable friction change.
  none,

  /// Shift from stick state to slip state.
  slip,

  /// A sudden slip release of built-up static friction energy.
  slipRelease,

  /// A minor fluctuation in dynamic friction.
  microSlip,

  /// Shift from slip state back to stationary stick.
  stick,
}

/// Defines the type of friction-related events produced by the [StickSlipController].
sealed class StickSlipEvent {
  const StickSlipEvent();

  /// No significant friction state change.
  const factory StickSlipEvent.none() = _NoneEvent;

  /// Transition from stick (stationary) to slip (moving).
  const factory StickSlipEvent.slip() = _SlipEvent;

  /// Micro-vibration event caused by slip instability.
  const factory StickSlipEvent.microSlip({required double intensity}) =
      _MicroSlipEvent;

  /// Sudden energy release when a stick condition breaks.
  const factory StickSlipEvent.slipRelease({required double intensity}) =
      _SlipReleaseEvent;

  /// Transition from slip (moving) back to stick (stationary).
  const factory StickSlipEvent.stick() = _StickEvent;

  /// The designated category of friction release.
  StickSlipEventType get type;

  /// The modeled intensity (0.0 to 1.0) of the friction release.
  double get intensity;

  /// Returns the simulated vibration amplitude (0.0 to 1.0) for this event.
  double get amplitude => switch (this) {
        _NoneEvent() => 0.0,
        _SlipEvent() => 0.4,
        _MicroSlipEvent(intensity: final i) => i,
        _SlipReleaseEvent(intensity: final i) => i,
        _StickEvent() => 0.05,
      };
}

class _NoneEvent extends StickSlipEvent {
  const _NoneEvent();
  @override
  StickSlipEventType get type => StickSlipEventType.none;
  @override
  double get intensity => 0.0;
}

class _SlipEvent extends StickSlipEvent {
  const _SlipEvent();
  @override
  StickSlipEventType get type => StickSlipEventType.slip;
  @override
  double get intensity => 0.4;
}

class _MicroSlipEvent extends StickSlipEvent {
  @override
  final double intensity;
  const _MicroSlipEvent({required this.intensity});
  @override
  StickSlipEventType get type => StickSlipEventType.microSlip;
}

class _SlipReleaseEvent extends StickSlipEvent {
  @override
  final double intensity;
  const _SlipReleaseEvent({required this.intensity});
  @override
  StickSlipEventType get type => StickSlipEventType.slipRelease;
}

class _StickEvent extends StickSlipEvent {
  const _StickEvent();
  @override
  StickSlipEventType get type => StickSlipEventType.stick;
  @override
  double get intensity => 0.05;
}

/// A specialized controller for simulating stick-slip friction oscillations.
///
/// Models the accumulation of elastic energy during "stick" phases and the
/// sudden release of that energy during "slip" transitions.
class StickSlipController {
  bool _initialized = false;
  bool _wasStationary = true;
  double _lastVelocity = 0;
  double _stickEnergy = 0;
  int _lastMoveTimeMs = DateTime.now().millisecondsSinceEpoch;

  int _stationaryThresholdMs = 50;
  double _slipVelocityThreshold = 0.05;

  /// Time limit before zero-velocity qualifies as strongly adhered stiction.
  set stationaryThresholdMs(int value) => _stationaryThresholdMs = value;

  /// Point at which sliding becomes continuous.
  set slipVelocityThreshold(double value) => _slipVelocityThreshold = value;

  /// Ticks the internal simulation according to the instantaneous [velocity].
  /// [timestampMs] allows callers to inject a monotonic timestamp for
  /// deterministic testing and to avoid DateTime.now() jitter.
  StickSlipEvent update(double velocity, {int? timestampMs}) {
    final now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final dt = (now - _lastMoveTimeMs).clamp(1, 100);

    if (!_initialized) {
      _initialized = true;
      _lastVelocity = velocity;
      _lastMoveTimeMs = now;
      _wasStationary = velocity < _slipVelocityThreshold;
      return const StickSlipEvent.none();
    }

    final accel = (velocity - _lastVelocity).abs();

    if (velocity < _slipVelocityThreshold) {
      if (!_wasStationary) {
        if (dt > _stationaryThresholdMs) {
          _wasStationary = true;
          _stickEnergy = 0.0;
        }
      } else {
        _stickEnergy = (_stickEnergy + dt * 0.001).clamp(0.0, 1.0);
      }
      _lastMoveTimeMs = now;
      _lastVelocity = velocity;
      return const StickSlipEvent.none();
    }

    if (_wasStationary) {
      _wasStationary = false;
      final releaseEnergy = _stickEnergy;
      _stickEnergy = 0.0;
      _lastVelocity = velocity;
      _lastMoveTimeMs = now;
      return StickSlipEvent.slipRelease(intensity: releaseEnergy);
    }

    _lastVelocity = velocity;
    _lastMoveTimeMs = now;

    if (accel > 0.15) {
      return StickSlipEvent.microSlip(intensity: (accel * 2).clamp(0.0, 0.6));
    }

    return const StickSlipEvent.none();
  }

  /// Resets the controller state.
  void reset() {
    _initialized = false;
    _wasStationary = true;
    _lastVelocity = 0.0;
    _stickEnergy = 0.0;
    _lastMoveTimeMs = DateTime.now().millisecondsSinceEpoch;
  }
}
