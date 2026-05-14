import 'stick_slip_controller.dart';

/// A single frame of output from the paper physics engine.
class PaperPhysicsFrame {
  /// Creates a [PaperPhysicsFrame] with the given physics values.
  const PaperPhysicsFrame({
    /// Haptic amplitude (0.0 to 1.0).
    required this.amplitude,

    /// Haptic sharpness (0.0 to 1.0).
    required this.sharpness,

    /// Haptic duration in milliseconds.
    required this.durationMs,

    /// Raw resistance value from the paper model.
    required this.rawResistance,

    /// Raw texture noise value.
    required this.rawTexture,

    /// Raw friction coefficient.
    required this.rawFriction,

    /// Optional stick-slip event (if triggered this frame).
    this.stickSlipEvent,
  });

  /// Haptic amplitude (0.0 to 1.0).
  final double amplitude;

  /// Haptic sharpness (0.0 to 1.0).
  final double sharpness;

  /// Haptic duration in milliseconds.
  final int durationMs;

  /// Optional stick-slip event (if triggered this frame).
  final StickSlipEvent? stickSlipEvent;

  /// Raw resistance value from the paper model.
  final double rawResistance;

  /// Raw texture noise value.
  final double rawTexture;

  /// Raw friction coefficient.
  final double rawFriction;

  /// An empty / default frame with all values set to zero.
  static const empty = PaperPhysicsFrame(
    amplitude: 0,
    sharpness: 0,
    durationMs: 0,
    rawResistance: 0,
    rawTexture: 0,
    rawFriction: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperPhysicsFrame &&
          runtimeType == other.runtimeType &&
          amplitude == other.amplitude &&
          sharpness == other.sharpness &&
          durationMs == other.durationMs &&
          rawResistance == other.rawResistance &&
          rawTexture == other.rawTexture &&
          rawFriction == other.rawFriction &&
          stickSlipEvent == other.stickSlipEvent;

  @override
  int get hashCode =>
      amplitude.hashCode ^
      sharpness.hashCode ^
      durationMs.hashCode ^
      rawResistance.hashCode ^
      rawTexture.hashCode ^
      rawFriction.hashCode ^
      stickSlipEvent.hashCode;
}
