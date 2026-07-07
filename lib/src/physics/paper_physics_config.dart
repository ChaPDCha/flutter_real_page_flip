import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';

/// Configuration for paper physics simulation parameters.
///
/// Controls friction, texture noise, haptic timing, and stick-slip behaviour
/// to simulate different paper types (standard, thin bible, rough antique).
@immutable
class PaperPhysicsConfig {
  /// Creates a [PaperPhysicsConfig] with the given parameters.
  const PaperPhysicsConfig({
    /// Sigmoid curve steepness for resistance model.
    this.sigmoidK = 6.0,

    /// Sigmoid curve center point for resistance model.
    this.sigmoidCenter = 0.5,

    /// Binding stiffness at the spine (0.0 to 1.0).
    this.bindingStiffness = 0.5,

    /// Static friction coefficient.
    this.muStatic = 0.6,

    /// Kinetic friction coefficient.
    this.muKinetic = 0.25,

    /// Stribeck velocity threshold for friction transition.
    this.stribeckV0 = 0.08,

    /// Persistence (fractal roughness) for Perlin texture noise.
    this.perlinPersistence = 0.45,

    /// Number of octaves for Perlin noise synthesis.
    this.perlinOctaves = 4,

    /// Base frequency for Perlin noise.
    this.perlinBaseFreq = 0.08,

    /// Minimum interval (ms) between haptic throttle events.
    this.throttleIntervalMs = 18,

    /// Minimum haptic duration in milliseconds.
    this.minDurationMs = 8,

    /// Maximum haptic duration in milliseconds.
    this.maxDurationMs = 120,

    /// Time (ms) a page must be stationary to accumulate stick energy.
    this.stationaryThresholdMs = 100,

    /// Velocity threshold below which the page is considered stationary.
    this.slipVelocityThreshold = 0.05,

    /// Preset-level friction scale used by the haptic presentation layer.
    this.frictionScale = 0.2,

    /// Preset-level stiffness scale used by release and resistance haptics.
    this.stiffnessScale = 0.4,

    /// Preset-level roughness scale used by throttle and sharpness modulation.
    this.roughnessScale = 0.3,

    /// Preset-level base sharpness used by paper tick haptics.
    this.baseSharpness = 0.5,
  });

  /// Resolves the public texture preset into the single physics+haptic config.
  factory PaperPhysicsConfig.fromTexturePreset(PaperTexturePreset preset) =>
      switch (preset) {
        PaperTexturePreset.smooth => smoothPreset,
        PaperTexturePreset.standard => standardPreset,
        PaperTexturePreset.textured => texturedPreset,
        PaperTexturePreset.kraft => kraftPreset,
      };

  /// Sigmoid curve steepness for resistance model.
  final double sigmoidK;

  /// Sigmoid curve center point for resistance model.
  final double sigmoidCenter;

  /// Binding stiffness at the spine (0.0 to 1.0).
  final double bindingStiffness;

  /// Static friction coefficient.
  final double muStatic;

  /// Kinetic friction coefficient.
  final double muKinetic;

  /// Stribeck velocity threshold for friction transition.
  final double stribeckV0;

  /// Persistence (fractal roughness) for Perlin texture noise.
  final double perlinPersistence;

  /// Number of octaves for Perlin noise synthesis.
  final int perlinOctaves;

  /// Base frequency for Perlin noise.
  final double perlinBaseFreq;

  /// Minimum interval (ms) between haptic throttle events.
  final int throttleIntervalMs;

  /// Minimum haptic duration in milliseconds.
  final int minDurationMs;

  /// Maximum haptic duration in milliseconds.
  final int maxDurationMs;

  /// Time (ms) a page must be stationary to accumulate stick energy.
  final int stationaryThresholdMs;

  /// Velocity threshold below which the page is considered stationary.
  final double slipVelocityThreshold;

  /// Preset-level friction scale used by the haptic presentation layer.
  final double frictionScale;

  /// Preset-level stiffness scale used by release and resistance haptics.
  final double stiffnessScale;

  /// Preset-level roughness scale used by throttle and sharpness modulation.
  final double roughnessScale;

  /// Preset-level base sharpness used by paper tick haptics.
  final double baseSharpness;

  /// Default standard paper configuration.
  static const standard = PaperPhysicsConfig();

  /// Thin bible paper configuration (lower friction, less texture).
  static const thinBible = PaperPhysicsConfig(
    sigmoidK: 7.5,
    bindingStiffness: 0.7,
    muStatic: 0.55,
    muKinetic: 0.2,
    perlinPersistence: 0.42,
    perlinOctaves: 5,
    perlinBaseFreq: 0.12,
  );

  /// Rough antique paper configuration (higher friction, more texture).
  static const roughAntique = PaperPhysicsConfig(
    sigmoidK: 5,
    bindingStiffness: 0.3,
    muStatic: 0.8,
    muKinetic: 0.4,
    perlinPersistence: 0.6,
    perlinBaseFreq: 0.05,
    maxDurationMs: 180,
  );

  /// Smooth thin-paper preset: thin bible physics plus smooth texture scales.
  static const smoothPreset = PaperPhysicsConfig(
    sigmoidK: 7.5,
    bindingStiffness: 0.7,
    muStatic: 0.55,
    muKinetic: 0.2,
    perlinPersistence: 0.42,
    perlinOctaves: 5,
    perlinBaseFreq: 0.12,
    minDurationMs: 4,
    maxDurationMs: 16,
    frictionScale: 0.1,
    stiffnessScale: 0.2,
    roughnessScale: 0.1,
    baseSharpness: 0.8,
  );

  /// Standard paper preset: standard physics plus standard texture scales.
  static const standardPreset = PaperPhysicsConfig();

  /// Textured paper preset: rough antique physics plus textured scales.
  static const texturedPreset = PaperPhysicsConfig(
    sigmoidK: 5,
    bindingStiffness: 0.3,
    muStatic: 0.8,
    muKinetic: 0.4,
    perlinPersistence: 0.6,
    perlinBaseFreq: 0.05,
    maxDurationMs: 180,
    frictionScale: 0.5,
    stiffnessScale: 0.6,
    roughnessScale: 0.8,
    baseSharpness: 0.6,
  );

  /// Kraft paper preset: heavier friction with long-duration haptic output.
  static const kraftPreset = PaperPhysicsConfig(
    muStatic: 0.85,
    muKinetic: 0.5,
    perlinBaseFreq: 0.04,
    perlinPersistence: 0.7,
    minDurationMs: 12,
    maxDurationMs: 180,
    frictionScale: 0.7,
    stiffnessScale: 0.9,
    roughnessScale: 1.2,
    baseSharpness: 0.4,
  );

  /// Returns a copy of this config with the given fields replaced.
  PaperPhysicsConfig copyWith({
    double? sigmoidK,
    double? sigmoidCenter,
    double? bindingStiffness,
    double? muStatic,
    double? muKinetic,
    double? stribeckV0,
    double? perlinPersistence,
    int? perlinOctaves,
    double? perlinBaseFreq,
    int? throttleIntervalMs,
    int? minDurationMs,
    int? maxDurationMs,
    int? stationaryThresholdMs,
    double? slipVelocityThreshold,
    double? frictionScale,
    double? stiffnessScale,
    double? roughnessScale,
    double? baseSharpness,
  }) =>
      PaperPhysicsConfig(
        sigmoidK: sigmoidK ?? this.sigmoidK,
        sigmoidCenter: sigmoidCenter ?? this.sigmoidCenter,
        bindingStiffness: bindingStiffness ?? this.bindingStiffness,
        muStatic: muStatic ?? this.muStatic,
        muKinetic: muKinetic ?? this.muKinetic,
        stribeckV0: stribeckV0 ?? this.stribeckV0,
        perlinPersistence: perlinPersistence ?? this.perlinPersistence,
        perlinOctaves: perlinOctaves ?? this.perlinOctaves,
        perlinBaseFreq: perlinBaseFreq ?? this.perlinBaseFreq,
        throttleIntervalMs: throttleIntervalMs ?? this.throttleIntervalMs,
        minDurationMs: minDurationMs ?? this.minDurationMs,
        maxDurationMs: maxDurationMs ?? this.maxDurationMs,
        stationaryThresholdMs:
            stationaryThresholdMs ?? this.stationaryThresholdMs,
        slipVelocityThreshold:
            slipVelocityThreshold ?? this.slipVelocityThreshold,
        frictionScale: frictionScale ?? this.frictionScale,
        stiffnessScale: stiffnessScale ?? this.stiffnessScale,
        roughnessScale: roughnessScale ?? this.roughnessScale,
        baseSharpness: baseSharpness ?? this.baseSharpness,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperPhysicsConfig &&
          runtimeType == other.runtimeType &&
          sigmoidK == other.sigmoidK &&
          sigmoidCenter == other.sigmoidCenter &&
          bindingStiffness == other.bindingStiffness &&
          muStatic == other.muStatic &&
          muKinetic == other.muKinetic &&
          stribeckV0 == other.stribeckV0 &&
          perlinPersistence == other.perlinPersistence &&
          perlinOctaves == other.perlinOctaves &&
          perlinBaseFreq == other.perlinBaseFreq &&
          throttleIntervalMs == other.throttleIntervalMs &&
          minDurationMs == other.minDurationMs &&
          maxDurationMs == other.maxDurationMs &&
          stationaryThresholdMs == other.stationaryThresholdMs &&
          slipVelocityThreshold == other.slipVelocityThreshold &&
          frictionScale == other.frictionScale &&
          stiffnessScale == other.stiffnessScale &&
          roughnessScale == other.roughnessScale &&
          baseSharpness == other.baseSharpness;

  @override
  int get hashCode =>
      sigmoidK.hashCode ^
      sigmoidCenter.hashCode ^
      bindingStiffness.hashCode ^
      muStatic.hashCode ^
      muKinetic.hashCode ^
      stribeckV0.hashCode ^
      perlinPersistence.hashCode ^
      perlinOctaves.hashCode ^
      perlinBaseFreq.hashCode ^
      throttleIntervalMs.hashCode ^
      minDurationMs.hashCode ^
      maxDurationMs.hashCode ^
      stationaryThresholdMs.hashCode ^
      slipVelocityThreshold.hashCode ^
      frictionScale.hashCode ^
      stiffnessScale.hashCode ^
      roughnessScale.hashCode ^
      baseSharpness.hashCode;
}
