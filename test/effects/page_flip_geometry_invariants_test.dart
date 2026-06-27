import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipGeometry invariants', () {
    /// Helper to construct geometry with default params.
    PageFlipGeometry makeGeo({
      double progress = 0.5,
      bool isRightToLeft = true,
      Offset touchOffset = Offset.zero,
      Size size = const Size(400, 600),
      bool isDoubleSpread = false,
      bool isForward = true,
    }) {
      return PageFlipGeometry(
        progress: progress,
        isRightToLeft: isRightToLeft,
        touchOffset: touchOffset,
        size: size,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
      );
    }

    test('flapVisibleWidth >= 0 for all progress values', () {
      for (int i = 0; i <= 100; i++) {
        final p = i / 100.0;
        final geo = makeGeo(progress: p);
        expect(geo.flapVisibleWidth, greaterThanOrEqualTo(0),
            reason: 'progress=$p');

        final geoDS = makeGeo(progress: p, isDoubleSpread: true);
        expect(geoDS.flapVisibleWidth, greaterThanOrEqualTo(0),
            reason: 'double-spread progress=$p');
      }
    });

    test('foldX is within valid range for all modes', () {
      for (int i = 0; i <= 100; i++) {
        final p = i / 100.0;
        final size = const Size(400, 600);

        // Single mode: foldX in [spineX (0), width]
        final geo = makeGeo(progress: p, size: size);
        expect(geo.foldX, greaterThanOrEqualTo(geo.spineX));
        expect(geo.foldX, lessThanOrEqualTo(size.width),
            reason: 'single progress=$p foldX=${geo.foldX}');

        // Double-spread backward: foldX can be < spineX (moves left from spine)
        final geoDSBwd = makeGeo(
          progress: p,
          size: size,
          isDoubleSpread: true,
          isForward: false,
        );
        expect(geoDSBwd.foldX, greaterThanOrEqualTo(0.0),
            reason: 'DS bwd progress=$p foldX=${geoDSBwd.foldX}');
        expect(geoDSBwd.foldX, lessThanOrEqualTo(size.width));

        // Double-spread forward: foldX in [spineX, width]
        final geoDSFwd = makeGeo(
          progress: p,
          size: size,
          isDoubleSpread: true,
          isForward: true,
        );
        expect(geoDSFwd.foldX, greaterThanOrEqualTo(geoDSFwd.spineX),
            reason: 'DS fwd progress=$p foldX=${geoDSFwd.foldX} spineX=${geoDSFwd.spineX}');
        expect(geoDSFwd.foldX, lessThanOrEqualTo(size.width));
      }
    });

    test('shadowIntensity is 0 at progress=0/1, peaks at 0.5', () {
      final at0 = makeGeo(progress: 0.0).shadowIntensity;
      final at1 = makeGeo(progress: 1.0).shadowIntensity;
      expect(at0, closeTo(0.0, 1e-6));
      expect(at1, closeTo(0.0, 1e-6));

      double maxIntensity = 0;
      for (int i = 0; i <= 100; i++) {
        final p = i / 100.0;
        final s = makeGeo(progress: p).shadowIntensity;
        if (s > maxIntensity) maxIntensity = s;
      }
      // shadowIntensity = sin(pi * p), peak at p=0.5 is 1.0
      expect(maxIntensity, closeTo(1.0, 0.01));
    });

    test('curvatureAmount is 0 at progress=0/1', () {
      final at0 = makeGeo(progress: 0.0).curvatureAmount;
      final at1 = makeGeo(progress: 1.0).curvatureAmount;
      expect(at0, closeTo(0.0, 1e-6));
      expect(at1, closeTo(0.0, 1e-6));
    });

    test('angle is 0 at progress=0 and progress=1', () {
      final at0 = makeGeo(progress: 0.0).angle;
      final at1 = makeGeo(progress: 1.0).angle;
      expect(at0, equals(0.0));
      expect(at1, equals(0.0));
    });

    test('spineX depends on isDoubleSpread', () {
      final single = makeGeo(isDoubleSpread: false, size: const Size(400, 600));
      expect(single.spineX, equals(0.0));

      final ds = makeGeo(isDoubleSpread: true, size: const Size(400, 600));
      expect(ds.spineX, equals(200.0));
    });

    test('flapRightOfFold is false in single mode', () {
      for (int i = 0; i <= 10; i++) {
        final p = i / 10.0;
        final geoFwd = makeGeo(progress: p, isForward: true);
        final geoBwd = makeGeo(progress: p, isForward: false);
        expect(geoFwd.flapRightOfFold, isFalse,
            reason: 'single fwd progress=$p');
        expect(geoBwd.flapRightOfFold, isFalse,
            reason: 'single bwd progress=$p');
      }
    });

    test('flapLeft <= width for all progress values', () {
      for (int i = 0; i <= 100; i++) {
        final p = i / 100.0;
        final geo = makeGeo(progress: p, size: const Size(400, 600));
        expect(geo.flapLeft, lessThanOrEqualTo(400),
            reason: 'single progress=$p flapLeft=${geo.flapLeft}');

        // In double-spread, flapLeft can be to the right of spine (backward)
        final geoDS = makeGeo(
          progress: p,
          size: const Size(400, 600),
          isDoubleSpread: true,
        );
        expect(geoDS.flapLeft, lessThanOrEqualTo(400),
            reason: 'double progress=$p flapLeft=${geoDS.flapLeft}');
      }
    });

    test('touchOffset affects angle but not foldX', () {
      final geo1 = makeGeo(touchOffset: const Offset(0, 200));
      final geo2 = makeGeo(touchOffset: const Offset(0, 400));
      // foldX should be the same regardless of touch position
      expect(geo1.foldX, equals(geo2.foldX));
    });

    test('mirror symmetry: forward p vs backward 1-p', () {
      for (int i = 0; i <= 20; i++) {
        final p = i / 20.0;
        if (p <= 0 || p >= 1) continue;

        final size = const Size(400, 600);
        final fwd = makeGeo(
          progress: p,
          size: size,
          isForward: true,
          isDoubleSpread: true,
        );
        final bwd = makeGeo(
          progress: 1.0 - p,
          size: size,
          isForward: false,
          isDoubleSpread: true,
        );

        // In double-spread, forward's flapRightOfFold should be opposite
        // of backward's at symmetric progress
        expect(fwd.flapRightOfFold, isFalse,
            reason: 'DS fwd at p=$p');
        expect(bwd.flapRightOfFold, isTrue,
            reason: 'DS bwd at 1-p=${1-p}');
      }
    });

    test('various sizes produce valid geometries', () {
      final sizes = [
        const Size(200, 300),
        const Size(400, 600),
        const Size(800, 1200),
        const Size(100, 2000),
      ];
      for (final size in sizes) {
        for (int i = 0; i <= 10; i++) {
          final p = i / 10.0;
          final geo = makeGeo(progress: p, size: size);
          expect(geo.flapVisibleWidth, greaterThanOrEqualTo(0));
          expect(geo.foldX, greaterThanOrEqualTo(geo.spineX));
          expect(geo.foldX, lessThanOrEqualTo(size.width));
          expect(geo.shadowIntensity, greaterThanOrEqualTo(0));
          expect(geo.shadowIntensity, lessThanOrEqualTo(1));
        }
      }
    });

    test('random parameter combinations produce valid geometry', () {
      final rng = math.Random(42);
      for (int i = 0; i < 100; i++) {
        final progress = rng.nextDouble();
        final isRightToLeft = rng.nextBool();
        final touchDy = rng.nextDouble() * 600;
        final width = 200 + rng.nextDouble() * 600;
        final height = 200 + rng.nextDouble() * 1000;
        final isDoubleSpread = rng.nextBool();
        final isForward = rng.nextBool();

        final geo = PageFlipGeometry(
          progress: progress,
          isRightToLeft: isRightToLeft,
          touchOffset: Offset(0, touchDy),
          size: Size(width, height),
          isDoubleSpread: isDoubleSpread,
          isForward: isForward,
        );

        expect(geo.flapVisibleWidth, greaterThanOrEqualTo(0),
            reason: 'i=$i progress=$progress');
        expect(geo.flapLeft, lessThanOrEqualTo(width));
        // Double-spread backward: foldX can be < spineX (moves left from spine)
        if (geo.isDoubleSpread && !geo.isForward) {
          expect(geo.foldX, greaterThanOrEqualTo(0.0));
        } else {
          expect(geo.foldX, greaterThanOrEqualTo(geo.spineX));
        }
        expect(geo.foldX, lessThanOrEqualTo(width));
        expect(geo.shadowIntensity, greaterThanOrEqualTo(0));
        expect(geo.shadowIntensity, lessThanOrEqualTo(1));
        expect(geo.curvatureAmount, greaterThanOrEqualTo(0));
        expect(
            geo.transform.storage.every((v) => v.isFinite), isTrue);
      }
    });

    test('isRightToLeft does not affect geometry calculations', () {
      for (int i = 0; i <= 10; i++) {
        final p = i / 10.0;
        final ltr = makeGeo(progress: p, isRightToLeft: false);
        final rtl = makeGeo(progress: p, isRightToLeft: true);
        expect(ltr.flapVisibleWidth, equals(rtl.flapVisibleWidth));
        expect(ltr.foldX, equals(rtl.foldX));
        expect(ltr.shadowIntensity, equals(rtl.shadowIntensity));
      }
    });
  });
}
