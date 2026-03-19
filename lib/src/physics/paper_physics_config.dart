class PaperPhysicsConfig {
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

  final double sigmoidK;
  final double sigmoidCenter;
  final double bindingStiffness;
  final double muStatic;
  final double muKinetic;
  final double stribeckV0;
  final double perlinPersistence;
  final int perlinOctaves;
  final double perlinBaseFreq;
  final int throttleIntervalMs;
  final int minDurationMs;
  final int maxDurationMs;
  final int stationaryThresholdMs;
  final double slipVelocityThreshold;

  static const standard = PaperPhysicsConfig();

  static const thinBible = PaperPhysicsConfig(
    sigmoidK: 7.5,
    bindingStiffness: 0.7,
    muStatic: 0.5,
    muKinetic: 0.2,
    perlinPersistence: 0.35,
    perlinBaseFreq: 0.12,
  );

  static const roughAntique = PaperPhysicsConfig(
    sigmoidK: 5,
    bindingStiffness: 0.3,
    muStatic: 0.8,
    muKinetic: 0.4,
    perlinPersistence: 0.6,
    perlinBaseFreq: 0.05,
    maxDurationMs: 180,
  );

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
  }) => PaperPhysicsConfig(
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
    stationaryThresholdMs: stationaryThresholdMs ?? this.stationaryThresholdMs,
    slipVelocityThreshold: slipVelocityThreshold ?? this.slipVelocityThreshold,
  );
}
