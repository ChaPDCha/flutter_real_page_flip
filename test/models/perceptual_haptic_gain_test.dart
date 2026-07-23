import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';
import 'package:real_page_flip/src/models/haptic_strength.dart';
import 'package:real_page_flip/src/models/perceptual_haptic_gain.dart';

void main() {
  group('HapticStrength', () {
    test('user gains are ordered light < medium < heavy around 1.0', () {
      expect(HapticStrength.light.userGain, lessThan(HapticStrength.medium.userGain));
      expect(HapticStrength.medium.userGain, equals(1.0));
      expect(HapticStrength.heavy.userGain, greaterThan(HapticStrength.medium.userGain));
    });

    test('fromKey falls back to medium for unknown values', () {
      expect(HapticStrength.fromKey('light'), HapticStrength.light);
      expect(HapticStrength.fromKey('heavy'), HapticStrength.heavy);
      expect(HapticStrength.fromKey(null), HapticStrength.medium);
      expect(HapticStrength.fromKey('nope'), HapticStrength.medium);
    });
  });

  group('PerceptualHapticGain.deviceGain', () {
    test('premium iOS stays near reference (1.0)', () {
      expect(
        PerceptualHapticGain.deviceGain(
          resolvedQuality: HapticQuality.premium,
          platform: TargetPlatform.iOS,
        ),
        closeTo(1.0, 0.001),
      );
    });

    test('premium Android is slightly attenuated vs iOS reference', () {
      final ios = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.premium,
        platform: TargetPlatform.iOS,
      );
      final android = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.premium,
        platform: TargetPlatform.android,
      );
      expect(android, lessThan(ios));
      expect(android, greaterThan(0.8));
    });

    test('standard path is boosted for weak waveform motors', () {
      final premium = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.premium,
        platform: TargetPlatform.android,
      );
      final standard = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.standard,
        platform: TargetPlatform.android,
      );
      expect(standard, greaterThan(premium));
      expect(standard, greaterThan(1.0));
    });

    test('basic path is attenuated to counter harsh system impacts', () {
      final basic = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.basic,
        platform: TargetPlatform.android,
      );
      expect(basic, lessThan(1.0));
      expect(basic, greaterThan(0.6));
    });
  });

  group('PerceptualHapticGain.combined', () {
    test('multiplies device and user gains then clamps', () {
      final gain = PerceptualHapticGain.combined(
        resolvedQuality: HapticQuality.standard,
        platform: TargetPlatform.android,
        strength: HapticStrength.heavy,
      );
      final device = PerceptualHapticGain.deviceGain(
        resolvedQuality: HapticQuality.standard,
        platform: TargetPlatform.android,
      );
      expect(gain, closeTo(device * HapticStrength.heavy.userGain, 0.001));
    });

    test('apply scales amplitude without exceeding soft ceiling', () {
      expect(
        PerceptualHapticGain.apply(0.6, gain: 2.0),
        equals(PerceptualHapticGain.amplitudeCeiling),
      );
      expect(PerceptualHapticGain.apply(0.1, gain: 1.3), closeTo(0.13, 1e-9));
      expect(PerceptualHapticGain.apply(0, gain: 1.5), equals(0));
    });

    test('heavy on standard exceeds medium on same path', () {
      final medium = PerceptualHapticGain.combined(
        resolvedQuality: HapticQuality.standard,
        platform: TargetPlatform.android,
        strength: HapticStrength.medium,
      );
      final heavy = PerceptualHapticGain.combined(
        resolvedQuality: HapticQuality.standard,
        platform: TargetPlatform.android,
        strength: HapticStrength.heavy,
      );
      expect(heavy, greaterThan(medium));
    });
  });
}
