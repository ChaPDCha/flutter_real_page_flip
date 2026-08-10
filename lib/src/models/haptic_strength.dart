/// User-facing perceived intensity preference for page-flip haptics.
///
/// This is independent of `PaperTexturePreset` (material character) and
/// `HapticQuality` (native fidelity route). It only scales output gain.
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
  ///
  /// The old 0.72 / 1.0 / 1.38 ladder put adjacent steps 1.39x apart. Against
  /// authored bands that peaked near 0.22, that meant absolute deltas of
  /// ~0.08 in the most compressive part of the LRA/Taptic response — at or
  /// below the vibrotactile difference threshold, so the three settings read
  /// as one. Steps are now 1.8x / 1.45x over a band that reaches the motor's
  /// usable range.
  double get userGain => switch (this) {
        HapticStrength.light => 0.55,
        HapticStrength.medium => 1.0,
        HapticStrength.heavy => 1.45,
      };

  static HapticStrength fromKey(String? key) {
    for (final value in HapticStrength.values) {
      if (value.key == key) return value;
    }
    return HapticStrength.medium;
  }
}
