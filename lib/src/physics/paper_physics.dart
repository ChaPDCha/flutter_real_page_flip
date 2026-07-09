import 'package:real_page_flip/src/physics/paper_physics_config.dart';
import 'package:real_page_flip/src/physics/paper_physics_frame.dart';
import 'package:real_page_flip/src/physics/paper_resistance_model.dart';
import 'package:real_page_flip/src/physics/paper_texture_noise.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

/// Façade that orchestrates all paper physics components.
///
/// Drives a single, unified noise model and blends stick-slip continuously
/// into the amplitude output — no discrete event preemption.
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
  ///
  /// [dx] Drag delta in pixels.
  /// [foldAngle] Normalised fold progress (0–1, derived from flip progress).
  /// [screenWidth] Screen width in pixels for normalisation.
  /// [customConfig] Optional override config for this calculation.
  PaperPhysicsFrame calculate({
    /// Drag delta in pixels (raw value from the controller — the engine
    /// normalises it internally).
    required double dx,

    /// Normalised fold progress (0–1). This is the ACTUAL flip progress
    /// from the gesture controller, NOT a noise signal. The old model
    /// passed controller-generated pseudo-noise here which corrupted the
    /// resistance calculation — the engine now receives a clean geometry
    /// value and generates its own Perlin noise for texture.
    required double foldAngle,

    /// Screen width in pixels for normalisation.
    required double screenWidth,

    /// Optional override config for this calculation.
    PaperPhysicsConfig? customConfig,
  }) {
    final activeConfig = customConfig ?? config;

    final normalizedDx = dx.abs() / screenWidth;
    final velocity = (normalizedDx * 10).clamp(0.0, 1.0);

    _accumulatedDistance += normalizedDx;

    // --- Single unified noise source: Perlin-based fractal texture ---
    // The old system generated pseudo-noise in the controller AND Perlin
    // noise here, and passed the controller's noise as `foldAngle`, which
    // corrupted the resistance model. Now the engine is the sole noise
    // source and `foldAngle` is a clean geometric value.
    final texture = _textureNoise.paperTextureFromConfig(
      position: _accumulatedDistance,
      persistence: activeConfig.perlinPersistence,
      octaves: activeConfig.perlinOctaves,
      baseFrequency: activeConfig.perlinBaseFreq,
    );

    // --- Resistance model (clean geometry, no noise pollution) ---
    final resistance = PaperResistanceModel.resistance(
      foldAngle: foldAngle,
      sigmoidK: activeConfig.sigmoidK,
      sigmoidCenter: activeConfig.sigmoidCenter,
      bindingStiffness: activeConfig.bindingStiffness,
    );

    // --- Friction (Stribeck curve) ---
    final friction = PaperResistanceModel.frictionCoefficient(
      velocity: velocity,
      muStatic: activeConfig.muStatic,
      muKinetic: activeConfig.muKinetic,
      stribeckV0: activeConfig.stribeckV0,
    );

    // --- Stick-slip: continuous modulation, NOT discrete events ---
    _stickSlip.stationaryThresholdMs = activeConfig.stationaryThresholdMs;
    _stickSlip.slipVelocityThreshold = activeConfig.slipVelocityThreshold;
    final stickSlipModulation = _stickSlip.update(velocity);

    // --- Final amplitude with stick-slip modulation blended in ---
    var amplitude = PaperResistanceModel.hapticAmplitude(
      velocity: velocity,
      friction: friction,
      texture: texture,
      resistance: resistance,
    );

    // Blend stick-slip boost so it naturally perturbs the texture
    // rather than adding a separate top-level event.
    if (stickSlipModulation.amplitudeBoost > 0.001) {
      amplitude =
          (amplitude + stickSlipModulation.amplitudeBoost * (1.0 - amplitude))
              .clamp(0.0, 1.0);
    }

    final duration = PaperResistanceModel.hapticDuration(
      resistance: resistance,
      friction: friction,
      minDurationMs: activeConfig.minDurationMs,
      maxDurationMs: activeConfig.maxDurationMs,
    );

    var sharpness = (velocity * 0.5 + texture * 0.4 + 0.1).clamp(0.0, 1.0);

    // Apply stick-slip sharpness shift.
    if (stickSlipModulation.sharpnessShift != 0.0) {
      sharpness =
          (sharpness + stickSlipModulation.sharpnessShift).clamp(0.0, 1.0);
    }

    final hasSlip = stickSlipModulation.amplitudeBoost > 0.01;

    return PaperPhysicsFrame(
      amplitude: amplitude,
      sharpness: sharpness,
      durationMs: duration,
      stickSlipModulation: hasSlip ? stickSlipModulation : null,
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
