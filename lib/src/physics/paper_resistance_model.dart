import 'dart:math';

/// Provides mathematical models for paper resistance, friction, and haptic feedback.
abstract class PaperResistanceModel {
  const PaperResistanceModel._();

  /// Calculates structural resistance based on the [foldAngle].
  /// Uses a sigmoid function to represent the increasing stiffness near the binding.
  static double resistance({
    required double foldAngle,
    double sigmoidK = 6.0,
    double sigmoidCenter = 0.5,
    double bindingStiffness = 0.5,
  }) {
    final sigmoidValue =
        1.0 / (1.0 + exp(-sigmoidK * (foldAngle - sigmoidCenter)));
    final bindingComponent = sin(foldAngle * pi) * bindingStiffness * 0.3;
    final edgeBoost = foldAngle > 0.75 ? (foldAngle - 0.75) * 0.4 : 0;
    return (sigmoidValue * 0.3 + bindingComponent + edgeBoost).clamp(0.0, 1.0);
  }

  /// Calculates the dynamic friction coefficient using the Stribeck curve model.
  static double frictionCoefficient({
    required double velocity,
    double muStatic = 0.6,
    double muKinetic = 0.25,
    double stribeckV0 = 0.08,
  }) =>
      muKinetic + (muStatic - muKinetic) * exp(-velocity / stribeckV0);

  /// Synthesizes the final haptic vibration amplitude from various physical factors.
  static double hapticAmplitude({
    required double velocity,
    required double friction,
    required double texture,
    required double resistance,
  }) {
    final velocityComponent = velocity * 0.4;
    final frictionComponent = friction * 0.25;
    final textureComponent = texture * 0.2;
    final resistanceBoost = resistance > 0.75 ? (resistance - 0.75) * 0.4 : 0.0;
    final raw = velocityComponent +
        frictionComponent +
        textureComponent +
        resistanceBoost;
    return raw.clamp(0.05, 1.0);
  }

  /// Determines the auditory/haptic effect duration based on structural resistance.
  static int hapticDuration({
    required double resistance,
    required double friction,
    int minDurationMs = 8,
    int maxDurationMs = 120,
  }) {
    final baseDuration = minDurationMs.toDouble() +
        (resistance * (maxDurationMs - minDurationMs));
    final frictionBonus = friction * 20;
    return (baseDuration + frictionBonus).round().clamp(
          minDurationMs,
          maxDurationMs,
        );
  }
}
