import 'stick_slip_controller.dart';

/// Represents the calculated physical state of a page flip at a specific frame.
class PaperPhysicsFrame {
  /// Primary generic constructor for a physics frame result.
  const PaperPhysicsFrame({
    required this.amplitude,
    required this.sharpness,
    required this.durationMs,
    required this.rawResistance,
    required this.rawTexture,
    required this.rawFriction,
    this.stickSlipEvent,
  });

  /// The computed haptic feedback amplitude.
  final double amplitude;

  /// The computed auditory sharpness or brightness parameter.
  final double sharpness;

  /// The dynamic duration of the resulting haptic and audio effects.
  final int durationMs;

  /// A specific stick-slip interaction event, if one occurred this frame.
  final StickSlipEvent? stickSlipEvent;

  /// Underlying raw structural paper resistance calculated.
  final double rawResistance;

  /// Underlying raw Perlin texture noise sampled this frame.
  final double rawTexture;

  /// Underlying raw computed dry friction coefficient.
  final double rawFriction;

  /// A constant representing a blank physics frame with zero external forces.
  static const empty = PaperPhysicsFrame(
    amplitude: 0,
    sharpness: 0,
    durationMs: 0,
    rawResistance: 0,
    rawTexture: 0,
    rawFriction: 0,
  );
}
