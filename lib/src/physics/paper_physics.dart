import 'paper_physics_config.dart';
import 'paper_physics_frame.dart';
import 'paper_resistance_model.dart';
import 'paper_texture_noise.dart';
import 'stick_slip_controller.dart';

/// Façade that orchestrates all paper physics components.
class PaperPhysicsEngine {
  /// Creates a physics engine parameterized uniquely by [pageNumber] seed.
  PaperPhysicsEngine({
    required int pageNumber,
    this.config = PaperPhysicsConfig.standard,
  })  : _textureNoise = PaperTextureNoise(seed: pageNumber),
        _stickSlip = StickSlipController();
  final PaperTextureNoise _textureNoise;
  final StickSlipController _stickSlip;

  /// The active configuration defining tuning parameters.
  final PaperPhysicsConfig config;

  double _accumulatedDistance = 0;

  /// Calculates the current physical forces based on drag kinematics.
  PaperPhysicsFrame calculate({
    required double dx,
    required double foldAngle,
    required double screenWidth,
    PaperPhysicsConfig? customConfig,
  }) {
    final activeConfig = customConfig ?? config;

    // Preserve direction: dragging back should revisit same texture positions
    final normalizedDx = dx / screenWidth;
    final velocityAbs = normalizedDx.abs() * 10;

    _accumulatedDistance += normalizedDx; // Signed — allows bidirectional texture

    final texture = _textureNoise.paperTextureFromConfig(
      position: _accumulatedDistance,
      persistence: activeConfig.perlinPersistence,
      octaves: activeConfig.perlinOctaves,
      baseFrequency: activeConfig.perlinBaseFreq,
    );

    final resistance = PaperResistanceModel.resistance(
      foldAngle: foldAngle,
      sigmoidK: activeConfig.sigmoidK,
      sigmoidCenter: activeConfig.sigmoidCenter,
      bindingStiffness: activeConfig.bindingStiffness,
    );

    final friction = PaperResistanceModel.frictionCoefficient(
      velocity: velocityAbs.clamp(0.0, 1.0),
      muStatic: activeConfig.muStatic,
      muKinetic: activeConfig.muKinetic,
      stribeckV0: activeConfig.stribeckV0,
    );

    _stickSlip.stationaryThresholdMs = activeConfig.stationaryThresholdMs;
    _stickSlip.slipVelocityThreshold = activeConfig.slipVelocityThreshold;
    final stickSlipEvent = _stickSlip.update(velocityAbs);

    final amplitude = PaperResistanceModel.hapticAmplitude(
      velocity: velocityAbs,
      friction: friction,
      texture: texture,
      resistance: resistance,
    );

    final duration = PaperResistanceModel.hapticDuration(
      resistance: resistance,
      friction: friction,
      minDurationMs: activeConfig.minDurationMs,
      maxDurationMs: activeConfig.maxDurationMs,
    );

    final sharpness = (velocityAbs * 0.5 + texture * 0.4 + 0.1).clamp(0.0, 1.0);

    return PaperPhysicsFrame(
      amplitude: amplitude,
      sharpness: sharpness,
      durationMs: duration,
      stickSlipEvent: stickSlipEvent,
      rawResistance: resistance,
      rawTexture: texture,
      rawFriction: friction,
    );
  }

  /// Resets internal accumulators and physics state logic.
  void reset() {
    _accumulatedDistance = 0.0;
    _stickSlip.reset();
  }
}
