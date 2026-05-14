import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipGeometry', () {
    test('foldX at progress=0 equals full width', () {
      final geo = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(400, 0.001));
    });

    test('foldX at progress=1 equals 0', () {
      final geo = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(0, 0.001));
    });

    test('foldX at progress=0.5 is half width', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(200, 0.001));
    });

    test('shadowIntensity peaks at progress=0.5', () {
      final at0 = PageFlipGeometry(
        progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      ).shadowIntensity;
      final atMid = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      ).shadowIntensity;
      final at1 = PageFlipGeometry(
        progress: 1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      ).shadowIntensity;

      expect(at0, closeTo(0, 0.001));
      expect(atMid, greaterThan(0.9));
      expect(at1, closeTo(0, 0.001));
    });

    test('flapVisibleWidth increases with progress', () {
      final atStart = PageFlipGeometry(
        progress: 0.1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      ).flapVisibleWidth;
      final atEnd = PageFlipGeometry(
        progress: 0.9, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      ).flapVisibleWidth;

      expect(atEnd, greaterThan(atStart));
    });
  });
}
