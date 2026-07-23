/// User-facing perceived intensity preference for page-flip haptics.
///
/// This is independent of [PaperTexturePreset] (material character) and
/// [HapticQuality] (native fidelity route). It only scales output gain.
enum HapticStrength {
  /// Quieter scrape / settle — useful on high-output flagship motors.
  light('light'),

  /// Reference preference used for perceptual tuning.
  medium('medium'),

  /// Louder scrape / settle — useful on weak mid-range motors.
  heavy('heavy');

  const HapticStrength(this.key);

  final String key;

  /// Relative gain versus [medium] (= 1.0).
  double get userGain => switch (this) {
        HapticStrength.light => 0.72,
        HapticStrength.medium => 1.0,
        HapticStrength.heavy => 1.38,
      };

  static HapticStrength fromKey(String? key) {
    for (final value in HapticStrength.values) {
      if (value.key == key) return value;
    }
    return HapticStrength.medium;
  }
}
