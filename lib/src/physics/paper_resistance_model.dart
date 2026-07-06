import 'dart:math';

/// Static utility class for paper resistance and friction calculations.
abstract class PaperResistanceModel {
  const PaperResistanceModel._();

  /// Calculates the resistance force based on fold angle and binding stiffness.
  ///
  /// Uses a sigmoid curve with a binding component and edge boost to
  /// simulate realistic paper resistance during folding.
  static double resistance({
    /// Current fold angle in radians.
    required double foldAngle,

    /// Sigmoid curve steepness.
    double sigmoidK = 6.0,

    /// Sigmoid curve center point.
    double sigmoidCenter = 0.5,

    /// Binding stiffness at the spine (0.0 to 1.0).
    double bindingStiffness = 0.5,
  }) {
    final sigmoidValue =
        1.0 / (1.0 + exp(-sigmoidK * (foldAngle - sigmoidCenter)));
    final bindingComponent = sin(foldAngle * pi) * bindingStiffness * 0.3;
    final edgeBoost = foldAngle > 0.75 ? (foldAngle - 0.75) * 0.4 : 0;
    return (sigmoidValue * 0.3 + bindingComponent + edgeBoost).clamp(0.0, 1.0);
  }

  /// Calculates the friction coefficient using the Stribeck friction model.
  static double frictionCoefficient({
    /// Normalised velocity (0.0 to 1.0).
    required double velocity,

    /// Static friction coefficient.
    double muStatic = 0.6,

    /// Kinetic friction coefficient.
    double muKinetic = 0.25,

    /// Stribeck velocity threshold for the friction transition.
    double stribeckV0 = 0.08,
  }) =>
      muKinetic + (muStatic - muKinetic) * exp(-velocity / stribeckV0);

  /// Calculates the haptic amplitude from velocity, friction, texture, and resistance.
  static double hapticAmplitude({
    /// Normalised velocity (0.0 to 1.0).
    required double velocity,

    /// Friction coefficient from [frictionCoefficient].
    required double friction,

    /// Texture noise value from Perlin noise.
    required double texture,

    /// Resistance value from [resistance].
    required double resistance,
  }) {
    final velocityComponent = velocity * 0.35;
    final frictionComponent = friction * 0.32;
    final textureComponent = texture * 0.25;
    final resistanceBoost = resistance > 0.75 ? (resistance - 0.75) * 0.4 : 0.0;

    final raw = velocityComponent +
        frictionComponent +
        textureComponent +
        resistanceBoost;

    // Gamma correction (pow 0.7) simulates logarithmic human tactile perception (Weber-Fechner Law),
    // boosting micro-textures at slow drag speeds and smoothing high-speed saturation.
    final corrected = pow(raw.clamp(0.0, 1.0), 0.7).toDouble();
    return corrected.clamp(0.05, 1.0);
  }

  /// Calculates the haptic vibration duration from resistance and friction.
  static int hapticDuration({
    /// Resistance value from [resistance].
    required double resistance,

    /// Friction coefficient from [frictionCoefficient].
    required double friction,

    /// Minimum duration in milliseconds.
    int minDurationMs = 8,

    /// Maximum duration in milliseconds.
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
