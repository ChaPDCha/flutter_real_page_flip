import 'package:real_page_flip/src/physics/paper_physics_config.dart';
import 'package:real_page_flip/src/physics/paper_physics_frame.dart';
import 'package:real_page_flip/src/physics/paper_resistance_model.dart';
import 'package:real_page_flip/src/physics/paper_texture_noise.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

/// Façade that orchestrates all paper physics components.
class PaperPhysicsEngine {
  /// Creates a [PaperPhysicsEngine] for the given page number.
  PaperPhysicsEngine({
    required int pageNumber,
    /// Configuration for paper physics parameters.
    this.config = PaperPhysicsConfig.standard,
  })  : _textureNoise = PaperTextureNoise(seed: pageNumber),
        _stickSlip = StickSlipController(
          stationaryThresholdMs: config.stationaryThresholdMs,
          slipVelocityThreshold: config.slipVelocityThreshold,
        );

  /// Configuration for paper physics parameters.
  final PaperPhysicsConfig config;

  final PaperTextureNoise _textureNoise;
  final StickSlipController _stickSlip;
  double _accumulatedDistance = 0;

  /// Calculates a physics frame for the given drag input.
  PaperPhysicsFrame calculate({
    /// Drag delta in pixels.
    required double dx,

    /// Current fold angle in radians.
    required double foldAngle,

    /// Screen width in pixels for normalization.
    required double screenWidth,

    /// Optional override config for this calculation.
    PaperPhysicsConfig? customConfig,
  }) {
    final activeConfig = customConfig ?? config;

    final normalizedDx = dx.abs() / screenWidth;
    final velocity = (normalizedDx * 10).clamp(0.0, 1.0);

    _accumulatedDistance += normalizedDx;

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
      velocity: velocity,
      muStatic: activeConfig.muStatic,
      muKinetic: activeConfig.muKinetic,
      stribeckV0: activeConfig.stribeckV0,
    );

    _stickSlip.stationaryThresholdMs = activeConfig.stationaryThresholdMs;
    _stickSlip.slipVelocityThreshold = activeConfig.slipVelocityThreshold;
    final stickSlipEvent = _stickSlip.update(velocity);

    final amplitude = PaperResistanceModel.hapticAmplitude(
      velocity: velocity,
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

    final sharpness = (velocity * 0.5 + texture * 0.4 + 0.1).clamp(0.0, 1.0);

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

  /// Resets the accumulated distance and stick-slip state.
  void reset() {
    _accumulatedDistance = 0.0;
    _stickSlip.reset();
  }
}
