import 'stick_slip_controller.dart';

class PaperPhysicsFrame {
  const PaperPhysicsFrame({
    required this.amplitude,
    required this.sharpness,
    required this.durationMs,
    required this.rawResistance,
    required this.rawTexture,
    required this.rawFriction,
    this.stickSlipEvent,
  });

  final double amplitude;
  final double sharpness;
  final int durationMs;
  final StickSlipEvent? stickSlipEvent;
  final double rawResistance;
  final double rawTexture;
  final double rawFriction;

  static const empty = PaperPhysicsFrame(
    amplitude: 0,
    sharpness: 0,
    durationMs: 0,
    rawResistance: 0,
    rawTexture: 0,
    rawFriction: 0,
  );
}
