/// Configuration class defining the physical parameters of the page flip engine.
class PaperPhysicsConfig {
  /// Creates a [PaperPhysicsConfig] with customizable physical parameters.
  const PaperPhysicsConfig({
    this.sigmoidK = 6.0,
    this.sigmoidCenter = 0.5,
    this.bindingStiffness = 0.5,
    this.muStatic = 0.6,
    this.muKinetic = 0.25,
    this.stribeckV0 = 0.08,
    this.perlinPersistence = 0.45,
    this.perlinOctaves = 4,
    this.perlinBaseFreq = 0.08,
    this.throttleIntervalMs = 18,
    this.minDurationMs = 8,
    this.maxDurationMs = 120,
    this.stationaryThresholdMs = 50,
    this.slipVelocityThreshold = 0.02,
  });

  /// Steepness curve of the resistance near the binding.
  final double sigmoidK;

  /// Center point of the resistance sigmoid curve.
  final double sigmoidCenter;

  /// Fundamental stiffness at the spine/binding.
  final double bindingStiffness;

  /// Static friction coefficient (grip).
  final double muStatic;

  /// Kinetic friction coefficient (slip).
  final double muKinetic;

  /// Stribeck velocity threshold parameter.
  final double stribeckV0;

  /// Persistence parameter for paper noise fractal.
  final double perlinPersistence;

  /// Number of octaves for paper noise fractal.
  final int perlinOctaves;

  /// Base frequency for paper noise fractal.
  final double perlinBaseFreq;

  /// Throttle interval for event generation in milliseconds.
  final int throttleIntervalMs;

  /// Minimum duration for a single physical haptic sensation.
  final int minDurationMs;

  /// Maximum duration for a single physical haptic sensation.
  final int maxDurationMs;

  /// Time threshold to consider the finger stationary.
  final int stationaryThresholdMs;

  /// Threshold velocity to trigger the slip state.
  final double slipVelocityThreshold;

  /// Standard paper configuration, mimicking a typical book page.
  static const standard = PaperPhysicsConfig();

  /// Configuration mimicking a thin, lightweight paper (e.g., bible paper).
  static const thinBible = PaperPhysicsConfig(
    sigmoidK: 7.5,
    bindingStiffness: 0.7,
    muStatic: 0.5,
    muKinetic: 0.2,
    perlinPersistence: 0.35,
    perlinBaseFreq: 0.12,
  );

  /// Configuration mimicking a rough, heavy antique paper.
  static const roughAntique = PaperPhysicsConfig(
    sigmoidK: 5,
    bindingStiffness: 0.3,
    muStatic: 0.8,
    muKinetic: 0.4,
    perlinPersistence: 0.6,
    perlinBaseFreq: 0.05,
    maxDurationMs: 180,
  );

  /// Creates a copy of this config, optionally replacing specific parameters.
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
      );
}
