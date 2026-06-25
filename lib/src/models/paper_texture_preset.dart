/// Intuitive paper texture presets for the haptic engine.
///
/// Each preset maps to a distinct set of vibration parameters that control
/// trigger sensitivity, intensity, duration, and tick density — creating
/// a noticeably different feel when dragging across pages.
enum PaperTexturePreset {
  /// 얇은 종이 — 부드럽고 미세한 진동, 높은 트리거 임계값
  smooth,

  /// 일반 종이 — 균형 잡힌 기본값
  standard,

  /// 거친 종이 — 중간 강도의 진동, 낮은 임계값
  textured,

  /// 크래프트지 — 강한 진동, 매우 낮은 임계값, 긴 지속시간
  kraft,
}

/// Concrete haptic parameters derived from a [PaperTexturePreset].
///
/// These values are consumed by [DefaultPageFlipEffectHandler] to modulate
/// the physics engine's output into motor-specific vibration commands.
class PaperTextureConfig {
  const PaperTextureConfig({
    required this.textureThreshold,
    required this.amplitudeScale,
    required this.durationMinMs,
    required this.durationMaxMs,
    required this.throttleFactor,
  });

  /// Resolves a preset to its concrete configuration.
  factory PaperTextureConfig.fromPreset(PaperTexturePreset preset) => switch (preset) {
    PaperTexturePreset.smooth => _smooth,
    PaperTexturePreset.standard => _standard,
    PaperTexturePreset.textured => _textured,
    PaperTexturePreset.kraft => _kraft,
  };

  /// Minimum raw texture value to trigger a texture tick.
  /// Higher values = harder to trigger (smoother feel).
  final double textureThreshold;

  /// Linear multiplier applied to the physics engine's amplitude output.
  /// 1.0 = raw physics value, <1.0 = subdued, >1.0 = amplified.
  final double amplitudeScale;

  /// Minimum vibration duration in milliseconds (clamped).
  final int durationMinMs;

  /// Maximum vibration duration in milliseconds (clamped).
  final int durationMaxMs;

  /// Relative throttle speed. 1.0 = standard rate.
  /// <1.0 = faster ticks (denser texture), >1.0 = slower ticks (sparser).
  final double throttleFactor;

  static const _smooth = PaperTextureConfig(
    textureThreshold: 0.75,
    amplitudeScale: 0.6,
    durationMinMs: 8,
    durationMaxMs: 18,
    throttleFactor: 1.5,
  );

  static const _standard = PaperTextureConfig(
    textureThreshold: 0.65,
    amplitudeScale: 1,
    durationMinMs: 10,
    durationMaxMs: 25,
    throttleFactor: 1,
  );

  static const _textured = PaperTextureConfig(
    textureThreshold: 0.50,
    amplitudeScale: 1.4,
    durationMinMs: 12,
    durationMaxMs: 35,
    throttleFactor: 0.8,
  );

  static const _kraft = PaperTextureConfig(
    textureThreshold: 0.40,
    amplitudeScale: 1.8,
    durationMinMs: 15,
    durationMaxMs: 40,
    throttleFactor: 0.6,
  );
}
