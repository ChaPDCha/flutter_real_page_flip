import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('flapFrontSourceRect', () {
    const imageSize = Size(800, 600);

    test('double spread forward flip uses left half of next spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(0));
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

    test('double spread backward flip uses right half of previous spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(400));
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

    test('double spread forward maps to left half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, equals(const Rect.fromLTWH(0, 0, 400, 600)));
    });

    test('double spread backward maps to right half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, equals(const Rect.fromLTWH(400, 0, 400, 600)));
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
}
