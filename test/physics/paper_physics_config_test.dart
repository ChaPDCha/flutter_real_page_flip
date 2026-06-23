import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('PaperPhysicsConfig', () {
    test('standard preset equals default constructor', () {
      expect(
        PaperPhysicsConfig.standard,
        equals(const PaperPhysicsConfig()),
      );
    });

    test('thinBible preset differs from standard', () {
      expect(
        PaperPhysicsConfig.thinBible,
        isNot(equals(PaperPhysicsConfig.standard)),
      );
    });

    test('roughAntique preset differs from standard', () {
      expect(
        PaperPhysicsConfig.roughAntique,
        isNot(equals(PaperPhysicsConfig.standard)),
      );
    });

    test('copyWith creates new instance, original unchanged', () {
      const original = PaperPhysicsConfig(sigmoidK: 6.0);
      final modified = original.copyWith(sigmoidK: 10.0);

      // Original unchanged
      expect(original.sigmoidK, equals(6.0));
      // Modified has new value
      expect(modified.sigmoidK, equals(10.0));
      // Different instances
      expect(identical(original, modified), isFalse);
    });

    test('copyWith only overrides specified field', () {
      const original = PaperPhysicsConfig(
        sigmoidK: 6.0,
        sigmoidCenter: 0.5,
        bindingStiffness: 0.5,
      );
      final modified = original.copyWith(sigmoidCenter: 0.7);

      expect(modified.sigmoidK, equals(6.0));
      expect(modified.sigmoidCenter, equals(0.7));
      expect(modified.bindingStiffness, equals(0.5));
    });

    test('equality with same values', () {
      const a = PaperPhysicsConfig(sigmoidK: 6.0, muStatic: 0.6);
      const b = PaperPhysicsConfig(sigmoidK: 6.0, muStatic: 0.6);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different values', () {
      const a = PaperPhysicsConfig(muStatic: 0.6);
      const b = PaperPhysicsConfig(muStatic: 0.8);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different muKinetic', () {
      const a = PaperPhysicsConfig(muKinetic: 0.25);
      const b = PaperPhysicsConfig(muKinetic: 0.35);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different stribeckV0', () {
      const a = PaperPhysicsConfig(stribeckV0: 0.08);
      const b = PaperPhysicsConfig(stribeckV0: 0.12);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different perlinPersistence', () {
      const a = PaperPhysicsConfig(perlinPersistence: 0.45);
      const b = PaperPhysicsConfig(perlinPersistence: 0.55);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different perlinOctaves', () {
      const a = PaperPhysicsConfig(perlinOctaves: 4);
      const b = PaperPhysicsConfig(perlinOctaves: 6);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different perlinBaseFreq', () {
      const a = PaperPhysicsConfig(perlinBaseFreq: 0.08);
      const b = PaperPhysicsConfig(perlinBaseFreq: 0.12);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different throttleIntervalMs', () {
      const a = PaperPhysicsConfig(throttleIntervalMs: 18);
      const b = PaperPhysicsConfig(throttleIntervalMs: 25);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different minDurationMs', () {
      const a = PaperPhysicsConfig(minDurationMs: 8);
      const b = PaperPhysicsConfig(minDurationMs: 12);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different maxDurationMs', () {
      const a = PaperPhysicsConfig(maxDurationMs: 120);
      const b = PaperPhysicsConfig(maxDurationMs: 150);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different stationaryThresholdMs', () {
      const a = PaperPhysicsConfig(stationaryThresholdMs: 50);
      const b = PaperPhysicsConfig(stationaryThresholdMs: 80);
      expect(a, isNot(equals(b)));
    });

    test('inequality with different slipVelocityThreshold', () {
      const a = PaperPhysicsConfig(slipVelocityThreshold: 0.02);
      const b = PaperPhysicsConfig(slipVelocityThreshold: 0.05);
      expect(a, isNot(equals(b)));
    });

    test('hashCode differs when fields differ', () {
      const a = PaperPhysicsConfig(
        sigmoidK: 6.0,
        muStatic: 0.6,
        muKinetic: 0.25,
        perlinOctaves: 4,
        throttleIntervalMs: 18,
      );
      const b = PaperPhysicsConfig(
        sigmoidK: 6.0,
        muStatic: 0.6,
        muKinetic: 0.25,
        perlinOctaves: 6,
        throttleIntervalMs: 18,
      );
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test('hashCode consistent for equal configs', () {
      const a =
          PaperPhysicsConfig(perlinBaseFreq: 0.08, stationaryThresholdMs: 50);
      const b =
          PaperPhysicsConfig(perlinBaseFreq: 0.08, stationaryThresholdMs: 50);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith overrides all fields independently', () {
      const original = PaperPhysicsConfig();
      for (final field in [
        original.copyWith(muKinetic: 0.5),
        original.copyWith(stribeckV0: 0.15),
        original.copyWith(perlinPersistence: 0.7),
        original.copyWith(perlinOctaves: 6),
        original.copyWith(perlinBaseFreq: 0.15),
        original.copyWith(throttleIntervalMs: 30),
        original.copyWith(minDurationMs: 15),
        original.copyWith(maxDurationMs: 200),
        original.copyWith(stationaryThresholdMs: 100),
        original.copyWith(slipVelocityThreshold: 0.08),
      ]) {
        expect(field, isNot(equals(original)));
      }
    });
  });
}
