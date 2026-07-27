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
/// On compact iPhones (SE, 12/13 mini), the iOS plugin previously reported
/// [hasAmplitudeControl] and [hasAdvancedHaptics] as `false` so
/// [HapticQuality.adaptive] resolved to [HapticQuality.basic] (settle-only).
///
/// As of v2.1.0 the native plugin has been removed and all platforms use
/// Flutter's built-in [HapticFeedback] API. The continuous waveform buzz was
/// not a compact-iPhone motor defect — it affects every iPhone Taptic Engine
/// when a MethodChannel streams amplitude arrays at ~25 Hz. The plugin removal
/// eliminates that path entirely, so all devices now get clean discrete ticks.
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
    if (requested == HapticQuality.premium &&
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
