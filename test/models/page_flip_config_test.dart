import 'package:flutter/material.dart';
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
  set viewportWidth(double width) {}

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
        flapContentRevealEnd: 0.95,
        flapBackStrength: 0.3,
        edgeTapPreviousLabel: 'Previous',
      );
      const b = PageFlipConfig(
        flapContentRevealEnd: 0.95,
        flapBackStrength: 0.3,
        edgeTapPreviousLabel: 'Previous',
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    // === NEW: Missing equality fields ===

    test('equality respects duration', () {
      const a = PageFlipConfig(duration: Duration(milliseconds: 450));
      const b = PageFlipConfig(duration: Duration(milliseconds: 300));
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects cutoffForward', () {
      const a = PageFlipConfig(cutoffForward: 0.4);
      const b = PageFlipConfig(cutoffForward: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects cutoffPrevious', () {
      const a = PageFlipConfig(cutoffPrevious: 0.4);
      const b = PageFlipConfig(cutoffPrevious: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects backgroundColor', () {
      const a = PageFlipConfig(backgroundColor: null);
      const b = PageFlipConfig(backgroundColor: Color(0xFF123456));
      expect(a == b, isFalse);
    });

    test('equality respects isRightSwipe', () {
      const a = PageFlipConfig(isRightSwipe: false);
      const b = PageFlipConfig(isRightSwipe: true);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableSwipe', () {
      const a = PageFlipConfig(enableSwipe: true);
      const b = PageFlipConfig(enableSwipe: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects sensitivity', () {
      const a = PageFlipConfig(sensitivity: 0.5);
      const b = PageFlipConfig(sensitivity: 1.0);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapWidthRatio', () {
      const a = PageFlipConfig(edgeTapWidthRatio: 0.1);
      const b = PageFlipConfig(edgeTapWidthRatio: 0.3);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects skipTapAnimation', () {
      const a = PageFlipConfig(skipTapAnimation: true);
      const b = PageFlipConfig(skipTapAnimation: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects thinPaperStrength', () {
      const a = PageFlipConfig(thinPaperStrength: 0.15);
      const b = PageFlipConfig(thinPaperStrength: 0.30);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects endRevealStrength', () {
      const a = PageFlipConfig(endRevealStrength: 0.35);
      const b = PageFlipConfig(endRevealStrength: 0.50);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapContentFadeOutEnd', () {
      const a = PageFlipConfig(flapContentFadeOutEnd: 0.20);
      const b = PageFlipConfig(flapContentFadeOutEnd: 0.30);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects performanceProfile', () {
      const a = PageFlipConfig(
        performanceProfile: DevicePerformanceProfile.high,
      );
      const b = PageFlipConfig(
        performanceProfile: DevicePerformanceProfile.low,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects hapticTexturePreset', () {
      const a = PageFlipConfig(
        hapticTexturePreset: PaperTexturePreset.standard,
      );
      const b = PageFlipConfig(
        hapticTexturePreset: PaperTexturePreset.kraft,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects semanticBuilder (null vs null)', () {
      const a = PageFlipConfig(semanticBuilder: null);
      const b = PageFlipConfig(semanticBuilder: null);
      expect(a == b, isTrue);
    });

    test('equality respects semanticBuilder (non-null vs null)', () {
      final builder = (int index, int total) => 'Page $index';
      final a = PageFlipConfig(semanticBuilder: builder);
      const b = PageFlipConfig(semanticBuilder: null);
      expect(a == b, isFalse);
    });

    test('all 26 fields produce distinct configs', () {
      // Verify that changing any single field from defaults produces inequality
      const base = PageFlipConfig();
      final variants = <PageFlipConfig>[
        const PageFlipConfig(duration: Duration(milliseconds: 300)),
        const PageFlipConfig(cutoffForward: 0.5),
        const PageFlipConfig(cutoffPrevious: 0.5),
        const PageFlipConfig(backgroundColor: Color(0xFF123456)),
        const PageFlipConfig(isRightSwipe: true),
        const PageFlipConfig(enableSwipe: false),
        const PageFlipConfig(sensitivity: 1.0),
        const PageFlipConfig(edgeTapWidthRatio: 0.3),
        const PageFlipConfig(skipTapAnimation: false),
        const PageFlipConfig(enableHaptics: false),
        const PageFlipConfig(enableSound: false),
        const PageFlipConfig(paperOpacity: 0.5),
        const PageFlipConfig(thinPaperStrength: 0.3),
        const PageFlipConfig(endRevealStrength: 0.5),
        const PageFlipConfig(flapContentFadeOutEnd: 0.3),
        const PageFlipConfig(flapContentRevealStart: 0.7),
        const PageFlipConfig(flapContentRevealEnd: 0.9),
        const PageFlipConfig(flapBackStrength: 0.5),
        const PageFlipConfig(
          performanceProfile: DevicePerformanceProfile.low,
        ),
        const PageFlipConfig(
          hapticTexturePreset: PaperTexturePreset.kraft,
        ),
      ];
      for (final v in variants) {
        expect(v == base, isFalse,
            reason: 'Variant should differ from base: $v');
      }
    });
  });
}
