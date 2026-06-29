import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Test helper: a custom effect handler for copyWith identity tests.
class _CopyWithHandler implements PageFlipEffectHandler {
  const _CopyWithHandler();

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
  group('PageFlipConfig.copyWith', () {
    const base = PageFlipConfig();

    test('no arguments returns identical config', () {
      final copy = base.copyWith();
      expect(copy, equals(base));
    });

    test('copyWith returns new instance (not identical)', () {
      final copy = base.copyWith();
      expect(identical(copy, base), isFalse);
    });

    test('copyWith duration', () {
      final copy = base.copyWith(duration: const Duration(milliseconds: 300));
      expect(copy.duration, const Duration(milliseconds: 300));
      expect(copy, isNot(equals(base)));
    });

    test('copyWith cutoffForward', () {
      final copy = base.copyWith(cutoffForward: 0.5);
      expect(copy.cutoffForward, 0.5);
    });

    test('copyWith cutoffPrevious', () {
      final copy = base.copyWith(cutoffPrevious: 0.6);
      expect(copy.cutoffPrevious, 0.6);
    });

    test('copyWith backgroundColor (null to non-null)', () {
      final copy = base.copyWith(backgroundColor: const Color(0xFF123456));
      expect(copy.backgroundColor, const Color(0xFF123456));
    });

    test('copyWith backgroundColor (non-null to null)', () {
      const colored = PageFlipConfig(backgroundColor: Color(0xFF123456));
      final copy = colored.copyWith(clearBackgroundColor: true);
      expect(copy.backgroundColor, isNull);
    });

    test('copyWith isRightSwipe', () {
      final copy = base.copyWith(isRightSwipe: true);
      expect(copy.isRightSwipe, isTrue);
    });

    test('copyWith enableSwipe', () {
      final copy = base.copyWith(enableSwipe: false);
      expect(copy.enableSwipe, isFalse);
    });

    test('copyWith sensitivity', () {
      final copy = base.copyWith(sensitivity: 0.8);
      expect(copy.sensitivity, 0.8);
    });

    test('copyWith edgeTapWidthRatio', () {
      final copy = base.copyWith(edgeTapWidthRatio: 0.2);
      expect(copy.edgeTapWidthRatio, 0.2);
    });

    test('copyWith skipTapAnimation', () {
      final copy = base.copyWith(skipTapAnimation: false);
      expect(copy.skipTapAnimation, isFalse);
    });

    test('copyWith semanticBuilder (null to non-null)', () {
      String builder(int index, int total) => 'Page $index of $total';
      final copy = base.copyWith(semanticBuilder: builder);
      expect(copy.semanticBuilder, same(builder));
    });

    test('copyWith semanticBuilder (non-null to null)', () {
      String builder(int index, int total) => 'Page $index';
      final withBuilder =
          const PageFlipConfig().copyWith(semanticBuilder: builder);
      expect(withBuilder.semanticBuilder, isNotNull);
      final cleared = withBuilder.copyWith(clearSemanticBuilder: true);
      expect(cleared.semanticBuilder, isNull);
    });

    test('copyWith edgeTapPreviousLabel', () {
      final copy = base.copyWith(edgeTapPreviousLabel: 'Prev');
      expect(copy.edgeTapPreviousLabel, 'Prev');
    });

    test('copyWith edgeTapNextLabel', () {
      final copy = base.copyWith(edgeTapNextLabel: 'Next');
      expect(copy.edgeTapNextLabel, 'Next');
    });

    test('copyWith edgeTapPreviousHint', () {
      final copy = base.copyWith(edgeTapPreviousHint: 'Go back');
      expect(copy.edgeTapPreviousHint, 'Go back');
    });

    test('copyWith edgeTapNextHint', () {
      final copy = base.copyWith(edgeTapNextHint: 'Go forward');
      expect(copy.edgeTapNextHint, 'Go forward');
    });

    test('copyWith enableHaptics', () {
      final copy = base.copyWith(enableHaptics: false);
      expect(copy.enableHaptics, isFalse);
    });

    test('copyWith enableSound', () {
      final copy = base.copyWith(enableSound: false);
      expect(copy.enableSound, isFalse);
    });

    test('copyWith effectHandler (null to non-null)', () {
      const handler = _CopyWithHandler();
      final copy = base.copyWith(effectHandler: handler);
      expect(copy.effectHandler, same(handler));
    });

    test('copyWith effectHandler (non-null to null)', () {
      final withHandler =
          base.copyWith(effectHandler: const _CopyWithHandler());
      final cleared = withHandler.copyWith(clearEffectHandler: true);
      expect(cleared.effectHandler, isNull);
    });

    test('copyWith paperOpacity', () {
      final copy = base.copyWith(paperOpacity: 0.5);
      expect(copy.paperOpacity, 0.5);
    });

    test('copyWith thinPaperStrength', () {
      final copy = base.copyWith(thinPaperStrength: 0.3);
      expect(copy.thinPaperStrength, 0.3);
    });

    test('copyWith endRevealStrength', () {
      final copy = base.copyWith(endRevealStrength: 0.5);
      expect(copy.endRevealStrength, 0.5);
    });

    test('copyWith flapContentFadeOutEnd', () {
      final copy = base.copyWith(flapContentFadeOutEnd: 0.3);
      expect(copy.flapContentFadeOutEnd, 0.3);
    });

    test('copyWith flapContentRevealStart', () {
      final copy = base.copyWith(flapContentRevealStart: 0.7);
      expect(copy.flapContentRevealStart, 0.7);
    });

    test('copyWith flapContentRevealEnd', () {
      final copy = base.copyWith(flapContentRevealEnd: 0.9);
      expect(copy.flapContentRevealEnd, 0.9);
    });

    test('copyWith flapBackStrength', () {
      final copy = base.copyWith(flapBackStrength: 0.5);
      expect(copy.flapBackStrength, 0.5);
    });

    test('copyWith performanceProfile', () {
      final copy = base.copyWith(
        performanceProfile: DevicePerformanceProfile.low,
      );
      expect(copy.performanceProfile, DevicePerformanceProfile.low);
    });

    test('copyWith hapticTexturePreset', () {
      final copy = base.copyWith(
        hapticTexturePreset: PaperTexturePreset.kraft,
      );
      expect(copy.hapticTexturePreset, PaperTexturePreset.kraft);
    });

    test('copyWith preserves unmodified fields', () {
      final copy = base.copyWith(duration: const Duration(milliseconds: 200));
      // All other fields should match base
      expect(copy.cutoffForward, base.cutoffForward);
      expect(copy.cutoffPrevious, base.cutoffPrevious);
      expect(copy.enableHaptics, base.enableHaptics);
      expect(copy.paperOpacity, base.paperOpacity);
      expect(copy.performanceProfile, base.performanceProfile);
    });

    test('multiple fields in single copyWith', () {
      final copy = base.copyWith(
        duration: const Duration(milliseconds: 200),
        sensitivity: 0.8,
        paperOpacity: 0.75,
        enableSound: false,
      );
      expect(copy.duration, const Duration(milliseconds: 200));
      expect(copy.sensitivity, 0.8);
      expect(copy.paperOpacity, 0.75);
      expect(copy.enableSound, isFalse);
    });
  });
}
