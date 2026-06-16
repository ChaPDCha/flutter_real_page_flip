import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('flapFrontSourceRect', () {
    const imageSize = Size(800, 600);

    test('double spread forward flip uses right half of current spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(400));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('single page forward flip uses full snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: false,
        isForward: true,
      );

      expect(rect, equals(const Rect.fromLTWH(0, 0, 800, 600)));
    });

    test('double spread backward flip uses left half of current spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(0));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('single page backward flip returns null (paper back only)', () {
      expect(
        flapFrontSourceRect(
          imageSize: imageSize,
          isDoubleSpread: false,
          isForward: false,
        ),
        isNull,
      );
    });
  });

  group('flapFrontDestRect', () {
    const size = Size(800, 600);

    test('double spread forward maps to right half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, equals(const Rect.fromLTWH(400, 0, 400, 600)));
    });

    test('double spread backward maps to left half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, equals(const Rect.fromLTWH(0, 0, 400, 600)));
    });

    test('single page uses full canvas', () {
      expect(
        flapFrontDestRect(
          size: size,
          isDoubleSpread: false,
          isForward: true,
        ),
        equals(const Rect.fromLTWH(0, 0, 800, 600)),
      );
      expect(
        flapFrontDestRect(
          size: size,
          isDoubleSpread: false,
          isForward: false,
        ),
        equals(const Rect.fromLTWH(0, 0, 800, 600)),
      );
    });
  });

  group('flapFrontContentRevealOpacity', () {
    test('starts visible and fades out quickly during early drag', () {
      expect(flapFrontContentRevealOpacity(0.0), equals(1.0));
      expect(
        flapFrontContentRevealOpacity(0.10, fadeOutEnd: 0.20),
        closeTo(0.5, 0.01),
      );
      expect(
        flapFrontContentRevealOpacity(0.20, fadeOutEnd: 0.20),
        equals(0.0),
      );
    });

    test('is zero during mid fold between fade-out and late reveal', () {
      expect(flapFrontContentRevealOpacity(0.25), equals(0.0));
      expect(flapFrontContentRevealOpacity(0.50), equals(0.0));
      expect(
        flapFrontContentRevealOpacity(0.84, revealStart: 0.85),
        equals(0.0),
      );
    });

    test('ramps smoothly during late settle reveal', () {
      expect(
        flapFrontContentRevealOpacity(
          0.90,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        closeTo(0.5, 0.01),
      );
    });

    test('is fully opaque at or after reveal end', () {
      expect(
        flapFrontContentRevealOpacity(
          0.95,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        equals(1.0),
      );
      expect(
        flapFrontContentRevealOpacity(
          1.0,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        equals(1.0),
      );
    });
  });
}
