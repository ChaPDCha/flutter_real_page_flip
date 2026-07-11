import 'package:flutter/foundation.dart';

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

  /// 진동 없음 — 효과음과 페이지 애니메이션은 유지
  ///
  /// Appended to preserve the persisted indices of the original presets.
  none,
}

/// Device-facing output envelope for one paper texture level.
@immutable
class PaperHapticOutputProfile {
  const PaperHapticOutputProfile({
    required this.level,
    required this.minAmplitude,
    required this.maxAmplitude,
    required this.sharpness,
    required this.samplesPerGrain,
  });

  final int level;
  final double minAmplitude;
  final double maxAmplitude;
  final double sharpness;

  /// Number of 5 ms waveform samples emitted for each movement grain.
  final int samplesPerGrain;
}

extension PaperTexturePresetHaptics on PaperTexturePreset {
  /// Stable user-facing strength level: none=0, paper presets=1..4.
  int get hapticLevel => switch (this) {
        PaperTexturePreset.none => 0,
        PaperTexturePreset.smooth => 1,
        PaperTexturePreset.standard => 2,
        PaperTexturePreset.textured => 3,
        PaperTexturePreset.kraft => 4,
      };

  bool get hapticsEnabled => this != PaperTexturePreset.none;

  /// Deliberately separated amplitude bands and pulse widths remain
  /// distinguishable on high-output flagship phone haptic motors.
  PaperHapticOutputProfile get hapticOutputProfile => switch (this) {
        PaperTexturePreset.none => const PaperHapticOutputProfile(
            level: 0,
            minAmplitude: 0,
            maxAmplitude: 0,
            sharpness: 0,
            samplesPerGrain: 0,
          ),
        PaperTexturePreset.smooth => const PaperHapticOutputProfile(
            level: 1,
            minAmplitude: 0.025,
            maxAmplitude: 0.10,
            sharpness: 0.92,
            samplesPerGrain: 1,
          ),
        PaperTexturePreset.standard => const PaperHapticOutputProfile(
            level: 2,
            minAmplitude: 0.07,
            maxAmplitude: 0.22,
            sharpness: 0.68,
            samplesPerGrain: 2,
          ),
        PaperTexturePreset.textured => const PaperHapticOutputProfile(
            level: 3,
            minAmplitude: 0.14,
            maxAmplitude: 0.38,
            sharpness: 0.48,
            samplesPerGrain: 3,
          ),
        PaperTexturePreset.kraft => const PaperHapticOutputProfile(
            level: 4,
            minAmplitude: 0.24,
            maxAmplitude: 0.55,
            sharpness: 0.24,
            samplesPerGrain: 4,
          ),
      };
}

/// Concrete haptic parameters derived from a [PaperTexturePreset].
///
/// Prefer `PaperPhysicsConfig.fromTexturePreset` for new internal code. This
/// class remains available for existing public callers.
@immutable
class PaperTextureConfig {
  const PaperTextureConfig({
    required this.friction,
    required this.stiffness,
    required this.roughness,
    this.baseSharpness = 0.5,
  });

  /// Resolves a preset to its concrete configuration.
  factory PaperTextureConfig.fromPreset(PaperTexturePreset preset) =>
      switch (preset) {
        PaperTexturePreset.smooth => _smooth,
        PaperTexturePreset.standard => _standard,
        PaperTexturePreset.textured => _textured,
        PaperTexturePreset.kraft => _kraft,
        PaperTexturePreset.none => _none,
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

  static const _none = PaperTextureConfig(
    friction: 0,
    stiffness: 0,
    roughness: 0,
    baseSharpness: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaperTextureConfig &&
          runtimeType == other.runtimeType &&
          friction == other.friction &&
          stiffness == other.stiffness &&
          roughness == other.roughness &&
          baseSharpness == other.baseSharpness;

  @override
  int get hashCode =>
      friction.hashCode ^
      stiffness.hashCode ^
      roughness.hashCode ^
      baseSharpness.hashCode;
}
