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
    required this.friction,
    required this.stiffness,
    required this.roughness,
    this.baseSharpness = 0.5,
  });

  /// Resolves a preset to its concrete configuration.
  factory PaperTextureConfig.fromPreset(PaperTexturePreset preset) => switch (preset) {
    PaperTexturePreset.smooth => _smooth,
    PaperTexturePreset.standard => _standard,
    PaperTexturePreset.textured => _textured,
    PaperTexturePreset.kraft => _kraft,
  };

  /// 마찰 계수 (0.0 ~ 1.0). 드래그 시 발생하는 미세 진동의 기본 강도와 밀도.
  final double friction;

  /// 종이의 강성 (0.0 ~ 1.0). 종이가 꺾일 때의 저항력 (Release 시 Thud 강도).
  final double stiffness;

  /// 거칠기 분산 (0.0 ~ 2.0). 노이즈 출력에 곱해져 진동 주기를 불규칙하게 만듦.
  final double roughness;

  /// 기본 날카로움 (0.0 ~ 1.0).
  final double baseSharpness;

  static const _smooth = PaperTextureConfig(
    friction: 0.1,
    stiffness: 0.2,
    roughness: 0.1,
    baseSharpness: 0.8, // 얇고 바스락거림
  );

  static const _standard = PaperTextureConfig(
    friction: 0.2,
    stiffness: 0.4,
    roughness: 0.3,
    baseSharpness: 0.5,
  );

  static const _textured = PaperTextureConfig(
    friction: 0.5,
    stiffness: 0.6,
    roughness: 0.8,
    baseSharpness: 0.6,
  );

  static const _kraft = PaperTextureConfig(
    friction: 0.7,
    stiffness: 0.9,
    roughness: 1.2,
    baseSharpness: 0.4, // 둔탁하고 두꺼운 느낌
  );
}
