/// Requested haptic fidelity. [adaptive] selects the best safe native path.
enum HapticQuality {
  /// Resolve from actual motor and OS capabilities.
  adaptive,

  /// No drag texture; only short semantic confirmation feedback.
  basic,

  /// Discrete drag ticks (amplitude-aware) — no continuous waveform.
  ///
  /// Used for mid-tier motors where continuous vibration reads as a buzz.
  standard,

  /// Full continuous texture, sharpness, and native primitives where present.
  premium,
}

/// Capability result returned by the native haptic implementation.
///
/// On compact iPhones (SE, 12/13 mini), the iOS plugin reports
/// [hasAmplitudeControl] and [hasAdvancedHaptics] as `false` even though Core
/// Haptics exists, so [HapticQuality.adaptive] resolves to
/// [HapticQuality.basic] (settle-only) instead of continuous premium drag
/// texture that buzzes harshly on small Taptic Engines.
class HapticCapabilities {
  const HapticCapabilities({
    required this.hasVibrator,
    required this.hasAmplitudeControl,
    required this.hasAdvancedHaptics,
  });

  const HapticCapabilities.basic()
      : hasVibrator = true,
        hasAmplitudeControl = false,
        hasAdvancedHaptics = false;

  final bool hasVibrator;
  final bool hasAmplitudeControl;
  final bool hasAdvancedHaptics;

  HapticQuality resolve(HapticQuality requested) {
    if (requested == HapticQuality.basic) return HapticQuality.basic;
    if ((requested == HapticQuality.premium ||
            requested == HapticQuality.adaptive) &&
        hasAdvancedHaptics &&
        hasAmplitudeControl) {
      return HapticQuality.premium;
    }
    if ((requested == HapticQuality.standard ||
            requested == HapticQuality.premium ||
            requested == HapticQuality.adaptive) &&
        hasAmplitudeControl) {
      return HapticQuality.standard;
    }
    return HapticQuality.basic;
  }
}
