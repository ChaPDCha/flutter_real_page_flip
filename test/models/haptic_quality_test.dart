import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart'
    show HapticCapabilities;

void main() {
  group('HapticCapabilities', () {
    test('adaptive resolves the highest supported quality', () {
      expect(
        const HapticCapabilities(
          hasVibrator: true,
          hasAmplitudeControl: true,
          hasAdvancedHaptics: true,
        ).resolve(HapticQuality.adaptive),
        HapticQuality.premium,
      );
      expect(
        const HapticCapabilities(
          hasVibrator: true,
          hasAmplitudeControl: true,
          hasAdvancedHaptics: false,
        ).resolve(HapticQuality.adaptive),
        HapticQuality.standard,
      );
      expect(
        const HapticCapabilities.basic().resolve(HapticQuality.adaptive),
        HapticQuality.basic,
      );
      expect(
        const HapticCapabilities(
          hasVibrator: true,
          hasAmplitudeControl: false,
          hasAdvancedHaptics: true,
        ).resolve(HapticQuality.adaptive),
        HapticQuality.basic,
      );
    });

    test('explicit quality never exceeds hardware capability', () {
      const capabilities = HapticCapabilities.basic();
      expect(
        capabilities.resolve(HapticQuality.premium),
        HapticQuality.basic,
      );
    });
  });
}
