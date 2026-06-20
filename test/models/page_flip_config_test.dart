import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// A minimal PageFlipEffectHandler for testing equality.
class _TestEffectHandler implements PageFlipEffectHandler {
  const _TestEffectHandler();

  @override
  void onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {}

  @override
  void dispose() {}
}

void main() {
  group('PageFlipConfig equality', () {
    test('identical instances are equal', () {
      const a = PageFlipConfig();
      expect(a == a, isTrue);
    });

    test('defaultSettings equals const PageFlipConfig()', () {
      expect(
        PageFlipConfig.defaultSettings,
        equals(const PageFlipConfig()),
      );
    });

    test('equality respects enableHaptics', () {
      const a = PageFlipConfig(enableHaptics: true);
      const b = PageFlipConfig(enableHaptics: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableSound', () {
      const a = PageFlipConfig(enableSound: true);
      const b = PageFlipConfig(enableSound: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects effectHandler (null vs null)', () {
      const a = PageFlipConfig(effectHandler: null);
      const b = PageFlipConfig(effectHandler: null);
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
    });

    test('equality respects effectHandler (non-null vs null)', () {
      const handler = _TestEffectHandler();
      final a = PageFlipConfig(effectHandler: handler);
      const b = PageFlipConfig(effectHandler: null);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects effectHandler (different instances)', () {
      final a = PageFlipConfig(effectHandler: _TestEffectHandler());
      final b = PageFlipConfig(effectHandler: _TestEffectHandler());
      expect(a == b, isFalse);
    });

    test('equality respects paperOpacity', () {
      const a = PageFlipConfig(paperOpacity: 1.0);
      const b = PageFlipConfig(paperOpacity: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapContentRevealStart', () {
      const a = PageFlipConfig(flapContentRevealStart: 0.85);
      const b = PageFlipConfig(flapContentRevealStart: 0.75);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapContentRevealEnd', () {
      const a = PageFlipConfig(flapContentRevealEnd: 0.95);
      const b = PageFlipConfig(flapContentRevealEnd: 0.90);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapBackStrength', () {
      const a = PageFlipConfig(flapBackStrength: 0.3);
      const b = PageFlipConfig(flapBackStrength: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapPreviousLabel', () {
      const a = PageFlipConfig(edgeTapPreviousLabel: 'Previous');
      const b = PageFlipConfig(edgeTapPreviousLabel: 'Back');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapNextLabel', () {
      const a = PageFlipConfig(edgeTapNextLabel: 'Next');
      const b = PageFlipConfig(edgeTapNextLabel: 'Forward');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapPreviousHint', () {
      const a = PageFlipConfig(edgeTapPreviousHint: 'Go to previous page');
      const b = PageFlipConfig(edgeTapPreviousHint: 'Go back');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapNextHint', () {
      const a = PageFlipConfig(edgeTapNextHint: 'Go to next page');
      const b = PageFlipConfig(edgeTapNextHint: 'Go forward');
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('hashCode consistent for equal configs', () {
      const a = PageFlipConfig(
        flapContentRevealEnd: 0.95, flapBackStrength: 0.3,
        edgeTapPreviousLabel: 'Previous',
      );
      const b = PageFlipConfig(
        flapContentRevealEnd: 0.95, flapBackStrength: 0.3,
        edgeTapPreviousLabel: 'Previous',
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
