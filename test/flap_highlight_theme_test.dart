import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

/// The curling paper should feel softly lit per theme: a warm matte sheen on
/// the light/Bible paper, and a faint cool ambient sheen on the pure-black
/// theme so the dark paper reads as a real surface (not a flat void). The
/// highlight must stay tiny in both themes — thin Bible paper is matte, so a
/// strong specular streak would look glassy/plastic.
void main() {
  group('per-theme highlight sheen', () {
    test('light/Bible paper is warm; pure-black is cool', () {
      final warm = flapHighlightTone(isPaperDark: false);
      final cool = flapHighlightTone(isPaperDark: true);
      // Warm paper white: red channel >= blue channel.
      expect(warm.r, greaterThanOrEqualTo(warm.b));
      // Cool ambient: blue channel > red channel.
      expect(cool.b, greaterThan(cool.r));
    });

    test('highlight stays matte (never glassy) in both themes', () {
      for (final dark in [true, false]) {
        expect(
          flapHighlightPeakBase(isPaperDark: dark),
          lessThanOrEqualTo(0.06),
          reason: 'highlight peak must stay tiny to avoid a glass/plastic look',
        );
        expect(
          flapHighlightMidBase(isPaperDark: dark),
          lessThan(flapHighlightPeakBase(isPaperDark: dark)),
        );
      }
    });

    test('pure-black sheen is dimmer than light-paper sheen', () {
      expect(
        flapHighlightPeakBase(isPaperDark: true),
        lessThan(flapHighlightPeakBase(isPaperDark: false)),
      );
    });
  });
}
