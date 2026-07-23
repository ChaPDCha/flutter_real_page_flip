import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';
import 'package:real_page_flip/src/models/haptic_strength.dart';

/// Maps absolute haptic amplitudes onto a more consistent *perceived* scale.
///
/// Absolute 0–1 intensities feel very different across:
/// - Core Haptics (premium iOS)
/// - Android composition primitives (premium Android)
/// - amplitude waveforms (standard)
/// - system UIImpact / one-shot fallbacks (basic)
///
/// [deviceGain] corrects the route; [HapticStrength.userGain] is the final
/// user override. Neither replaces texture presets — they only scale output.
class PerceptualHapticGain {
  const PerceptualHapticGain._();

  /// Soft ceiling so heavy + boosted routes cannot peg the motor.
  static const double amplitudeCeiling = 0.95;

  /// Route/platform gain relative to premium iOS (= 1.0).
  static double deviceGain({
    required HapticQuality resolvedQuality,
    required TargetPlatform platform,
  }) {
    final isCupertino = platform == TargetPlatform.iOS ||
        platform == TargetPlatform.macOS;
    return switch (resolvedQuality) {
      // Flagship Core Haptics / composition: keep near the authored bands.
      // Android primitives often read hotter than iOS for the same scale.
      HapticQuality.premium => isCupertino ? 1.0 : 0.90,
      // Waveform amplitude control without premium primitives tends to feel
      // thin on mid-range LRAs — lift the band toward the reference.
      HapticQuality.standard => isCupertino ? 1.18 : 1.30,
      // System light/medium/heavy impacts are coarse and often too punchy.
      HapticQuality.basic => isCupertino ? 0.82 : 0.78,
      // Requested adaptive should already be resolved before calling here.
      HapticQuality.adaptive => isCupertino ? 1.0 : 0.90,
    };
  }

  /// Combined device × user gain applied before native emission.
  static double combined({
    required HapticQuality resolvedQuality,
    required TargetPlatform platform,
    required HapticStrength strength,
  }) =>
      deviceGain(resolvedQuality: resolvedQuality, platform: platform) *
      strength.userGain;

  /// Scales a 0–1 amplitude/intensity by [gain] with a soft ceiling.
  static double apply(double amplitude, {required double gain}) {
    if (amplitude <= 0) return 0;
    return (amplitude * gain).clamp(0.0, amplitudeCeiling);
  }
}
