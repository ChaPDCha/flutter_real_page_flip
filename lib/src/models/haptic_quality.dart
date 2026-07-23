/// Requested haptic fidelity. [adaptive] selects the best safe native path.
enum HapticQuality {
  /// Resolve from actual motor and OS capabilities.
  adaptive,

  /// No drag texture; only short semantic confirmation feedback.
  basic,

  /// Amplitude-controlled waveform without premium texture detail.
  standard,

  /// Full continuous texture, sharpness, and native primitives where present.
  premium,
}

/// Capability result returned by the native haptic implementation.
///
/// On iPhone SE, the iOS plugin reports [hasAmplitudeControl] and
/// [hasAdvancedHaptics] as `false` even though Core Haptics exists, so
/// [HapticQuality.adaptive] resolves to [HapticQuality.basic] (settle-only)
/// instead of continuous premium drag texture that buzzes harshly.
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
