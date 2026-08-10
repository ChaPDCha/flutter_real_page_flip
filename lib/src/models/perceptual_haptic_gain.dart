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
    final isCupertino =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return switch (resolvedQuality) {
      // Flagship Core Haptics reads thinner than Android LRA waveforms at the
      // same authored 0–1 scale, so Cupertino premium stays the boosted
      // reference. Android premium was 0.90 — only 0.67x of iOS, which left
      // composition-primitive devices audibly weaker than iPhones at the same
      // setting. 1.10 closes that to 0.81x while staying below the reference.
      HapticQuality.premium => isCupertino ? 1.35 : 1.10,
      // Waveform amplitude control without premium primitives tends to feel
      // thin on mid-range LRAs — lift the band toward the reference.
      HapticQuality.standard => isCupertino ? 1.28 : 1.30,
      // System light/medium/heavy impacts are coarse, so this route stays
      // below the reference — but 0.82/0.78 pushed compact iPhones (SE, mini)
      // under the perceptual floor once the light user gain was applied.
      HapticQuality.basic => isCupertino ? 0.95 : 0.92,
      // Requested adaptive should already be resolved before calling here.
      HapticQuality.adaptive => isCupertino ? 1.35 : 1.10,
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
