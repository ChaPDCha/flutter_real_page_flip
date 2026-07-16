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

    test('defaults favor lightweight reader rendering', () {
      const config = PageFlipConfig();

      expect(config.flapBackStrength, equals(0.0));
      expect(config.doubleSpreadMidFoldBleed, equals(0.15));
      expect(config.singlePageBackContentOpacity, equals(0.35));
      expect(config.enableSinglePageSettleReveal, isTrue);
      expect(config.performanceProfile, DevicePerformanceProfile.medium);
    });

    test('equality respects doubleSpreadMidFoldBleed', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(doubleSpreadMidFoldBleed: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableHaptics', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(enableHaptics: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableSound', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(enableSound: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects effectHandler (null vs null)', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig();
      expect(a == b, isTrue);
      expect(a.hashCode == b.hashCode, isTrue);
    });

    test('equality respects effectHandler (non-null vs null)', () {
      const handler = _TestEffectHandler();
      const a = PageFlipConfig(effectHandler: handler);
      const b = PageFlipConfig();
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects effectHandler (different instances)', () {
      final a = PageFlipConfig(effectHandler: _TestEffectHandler());
      final b = PageFlipConfig(effectHandler: _TestEffectHandler());
      expect(a == b, isFalse);
    });

    test('equality respects paperOpacity', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(paperOpacity: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapContentRevealStart', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(flapContentRevealStart: 0.75);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapContentRevealEnd', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(flapContentRevealEnd: 0.90);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableSinglePageSettleReveal', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(enableSinglePageSettleReveal: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects flapBackStrength', () {
      const a = PageFlipConfig();
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
        edgeTapPreviousLabel: 'Previous',
      );
      const b = PageFlipConfig(
        edgeTapPreviousLabel: 'Previous',
      );
      expect(a.hashCode, equals(b.hashCode));
    });

    // === NEW: Missing equality fields ===

    test('equality respects duration', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(duration: Duration(milliseconds: 300));
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects cutoffForward', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(cutoffForward: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects cutoffPrevious', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(cutoffPrevious: 0.5);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects backgroundColor', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(backgroundColor: Color(0xFF123456));
      expect(a == b, isFalse);
    });

    test('equality respects isRightSwipe', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(isRightSwipe: true);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects enableSwipe', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(enableSwipe: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects sensitivity', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(sensitivity: 1);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects edgeTapWidthRatio', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(edgeTapWidthRatio: 0.3);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects skipTapAnimation', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(skipTapAnimation: false);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects thinPaperStrength', () {
      const a = PageFlipConfig();
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
      const a = PageFlipConfig();
      const b = PageFlipConfig(flapContentFadeOutEnd: 0.30);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects performanceProfile', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(
        performanceProfile: DevicePerformanceProfile.low,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects hapticTexturePreset', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(
        hapticTexturePreset: PaperTexturePreset.kraft,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects hapticQuality', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig(hapticQuality: HapticQuality.basic);
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('equality respects semanticBuilder (null vs null)', () {
      const a = PageFlipConfig();
      const b = PageFlipConfig();
      expect(a == b, isTrue);
    });

    test('equality respects semanticBuilder (non-null vs null)', () {
      String builder(int index, int total) => 'Page $index';
      final a = PageFlipConfig(semanticBuilder: builder);
      const b = PageFlipConfig();
      expect(a == b, isFalse);
    });

    test('all configurable fields produce distinct configs', () {
      // Verify that changing any single field from defaults produces inequality
      const base = PageFlipConfig();
      final variants = <PageFlipConfig>[
        const PageFlipConfig(duration: Duration(milliseconds: 300)),
        const PageFlipConfig(cutoffForward: 0.5),
        const PageFlipConfig(cutoffPrevious: 0.5),
        const PageFlipConfig(backgroundColor: Color(0xFF123456)),
        const PageFlipConfig(isRightSwipe: true),
        const PageFlipConfig(enableSwipe: false),
        const PageFlipConfig(sensitivity: 1),
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
        const PageFlipConfig(hapticQuality: HapticQuality.basic),
      ];
      for (final v in variants) {
        expect(
          v == base,
          isFalse,
          reason: 'Variant should differ from base: $v',
        );
      }
    });
  });

  group('PageFlipConfig normalization', () {
    test('returns the same instance when values are already safe', () {
      const config = PageFlipConfig();

      expect(identical(config.normalized, config), isTrue);
    });

    test('replaces unsafe duration values with bounded safe durations', () {
      expect(
        const PageFlipConfig(duration: Duration.zero).normalized.duration,
        PageFlipConfig.defaultSettings.duration,
      );
      expect(
        const PageFlipConfig(duration: Duration(days: 1)).normalized.duration,
        const Duration(seconds: 10),
      );
    });

    test('clamps gesture and visual strength values into safe ranges', () {
      const config = PageFlipConfig(
        cutoffForward: double.nan,
        cutoffPrevious: double.infinity,
        sensitivity: -4,
        edgeTapWidthRatio: 2,
        paperOpacity: -1,
        thinPaperStrength: 4,
        endRevealStrength: double.negativeInfinity,
        flapBackStrength: 8,
        singlePageBackContentOpacity: -2,
      );

      final normalized = config.normalized;

      expect(
        normalized.cutoffForward,
        PageFlipConfig.defaultSettings.cutoffForward,
      );
      expect(
        normalized.cutoffPrevious,
        PageFlipConfig.defaultSettings.cutoffPrevious,
      );
      expect(normalized.sensitivity, 0.0);
      expect(normalized.edgeTapWidthRatio, 0.5);
      expect(normalized.paperOpacity, 0.0);
      expect(normalized.thinPaperStrength, 1.0);
      expect(
        normalized.endRevealStrength,
        PageFlipConfig.defaultSettings.endRevealStrength,
      );
      expect(normalized.flapBackStrength, 1.0);
      expect(normalized.singlePageBackContentOpacity, 0.0);
    });

    test('orders flap reveal thresholds so phase math stays valid', () {
      const config = PageFlipConfig(
        flapContentFadeOutEnd: 0.9,
        flapContentRevealStart: 0.4,
        flapContentRevealEnd: 0.2,
      );

      final normalized = config.normalized;

      expect(normalized.flapContentFadeOutEnd, 0.4);
      expect(normalized.flapContentRevealStart, 0.4);
      expect(normalized.flapContentRevealEnd, 0.4);
    });

    test('preserves non-numeric callbacks and labels', () {
      String labelBuilder(int index, int total) => '$index/$total';
      const handler = _TestEffectHandler();
      final config = PageFlipConfig(
        semanticBuilder: labelBuilder,
        effectHandler: handler,
        edgeTapPreviousLabel: 'Back',
        edgeTapNextLabel: 'Next',
      );

      final normalized = config.normalized;

      expect(normalized.semanticBuilder, same(labelBuilder));
      expect(normalized.effectHandler, same(handler));
      expect(normalized.edgeTapPreviousLabel, 'Back');
      expect(normalized.edgeTapNextLabel, 'Next');
    });
  });
}
