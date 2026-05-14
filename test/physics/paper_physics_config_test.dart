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
  });
}
