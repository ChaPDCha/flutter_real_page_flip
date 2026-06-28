import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('buildStationaryPageClipPath ↔ buildFlapScreenClipPath alignment', () {
    const width = 800.0;
    const height = 600.0;
    const size = Size(width, height);

    // ---------------------------------------------------------------------------
    // Helper: find any X at a given Y where both paths contain the point.
    // Uses brute-force scan in screen space since flapLeft/foldX are
    // local coordinates and do not map linearly to screen-space positions.
    // Returns -1.0 if no overlap found (degenerate geometry).
    // ---------------------------------------------------------------------------
    double findOverlapX(Path stationaryPath, Path flapPath, double y) {
      for (double x = 0; x < width; x += 2.0) {
        if (stationaryPath.contains(Offset(x, y)) &&
            flapPath.contains(Offset(x, y))) {
          return x;
        }
      }
      return -1;
    }

    // ---------------------------------------------------------------------------
    // Helper: verify both paths overlap at a given Y.
    // ---------------------------------------------------------------------------
    void verifyOverlap(Path stationaryPath, Path flapPath, double y) {
      final overlapX = findOverlapX(stationaryPath, flapPath, y);
      expect(overlapX, greaterThanOrEqualTo(0.0),
          reason: 'No overlap found at y=$y. '
              'stationary contains at any X? '
              '${[
            0,
            200,
            400,
            600,
          ].map((x) => '($x,$y):${stationaryPath.contains(Offset(x.toDouble(), y))}').join(', ')}. '
              'flap contains at any X? '
              '${[
            0,
            200,
            400,
            600,
          ].map((x) => '($x,$y):${flapPath.contains(Offset(x.toDouble(), y))}').join(', ')}',);
    }

    // ---------------------------------------------------------------------------
    // Helper: check flap path is non-empty (covers a region in screen space).
    // Samples points between 0 and width at mid-height.
    // ---------------------------------------------------------------------------
    void expectFlapRegion(Path flapPath) {
      var found = false;
      for (double x = 0; x < width; x += 4.0) {
        if (flapPath.contains(Offset(x, height / 2))) {
          found = true;
          break;
        }
      }
      expect(found, isTrue, reason: 'flap path is empty at y=${height / 2}');
    }

    // ---------------------------------------------------------------------------
    // Tests
    // ---------------------------------------------------------------------------

    group('zero curvature (progress ≈ 0 or 1)', () {
      test('progress=0.15 — flap and stationary paths overlap', () {
        // Single forward: flap extends LEFT of foldX. Stationary path left of fold.
        final geo = PageFlipGeometry(
          progress: 0.15,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expect(stationaryPath.contains(const Offset(10, 300)), isTrue);
        expect(stationaryPath.contains(const Offset(width + 20, 300)), isFalse);

        expectFlapRegion(flapPath);

        verifyOverlap(stationaryPath, flapPath, height / 2);
      });

      test('progress=0.85 — late flip, flap and stationary paths overlap', () {
        final geo = PageFlipGeometry(
          progress: 0.85,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expectFlapRegion(flapPath);
        if (geo.flapLeft < geo.foldX - 0.5) {
          verifyOverlap(stationaryPath, flapPath, height / 2);
        }
      });
    });

    group('peak curvature (progress ≈ 0.5)', () {
      test('progress=0.5, touchOffset=center — curved fold line aligned', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expect(geo.curvatureAmount, greaterThan(0.001));
        expectFlapRegion(flapPath);

        // Verify overlap at top, middle, and bottom.
        for (final y in [50.0, height / 2, height - 50.0]) {
          verifyOverlap(stationaryPath, flapPath, y);
        }
      });

      test('progress=0.5 with upward touch offset', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: const Offset(0, -150),
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expect(geo.angle, isNot(closeTo(0.0, 0.001)));
        expectFlapRegion(flapPath);

        for (final y in [50.0, height / 2, height - 50.0]) {
          verifyOverlap(stationaryPath, flapPath, y);
        }
      });

      test('progress=0.5 with downward touch offset', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: const Offset(0, 150),
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expect(geo.angle, isNot(closeTo(0.0, 0.001)));
        expectFlapRegion(flapPath);

        for (final y in [50.0, height / 2, height - 50.0]) {
          verifyOverlap(stationaryPath, flapPath, y);
        }
      });
    });

    group('degenerate geometry', () {
      test('progress≈0 triggers degenerate guard', () {
        final geo = PageFlipGeometry(
          progress: 0.001,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final flapPath = buildFlapScreenClipPath(geo);
        // foldX ≈ pageWidth, flapVisibleWidth is tiny → degenerate.
        expect(flapPath.contains(const Offset(0, 0)), isFalse);
      });

      test(
          'progress≈1 does NOT trigger degenerate guard (flap spans full width)',
          () {
        final geo = PageFlipGeometry(
          progress: 0.999,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final flapPath = buildFlapScreenClipPath(geo);
        // foldX ≈ 0, flapVisibleWidth ≈ pageWidth → non-degenerate → valid region.
        expectFlapRegion(flapPath);
      });

      test('stationary path handles progress≈0 (full page visible)', () {
        final geo = PageFlipGeometry(
          progress: 0.001,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );
        // foldX ≈ pageWidth, so stationary covers [0, pageWidth] ≈ entire screen.
        final stationaryPath = buildStationaryPageClipPath(size, geo);
        expect(stationaryPath.contains(const Offset(width - 10, 300)), isTrue);
      });

      test('stationary path handles progress≈1 (almost turned)', () {
        final geo = PageFlipGeometry(
          progress: 0.999,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );
        // foldX ≈ 0, so stationary covers [0, ~1.5] only.
        final stationaryPath = buildStationaryPageClipPath(size, geo);
        expect(stationaryPath.contains(const Offset(0, 300)), isTrue);
      });
    });

    group('double-spread mode', () {
      test('forward flip — paths aligned at fold boundary', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
          isDoubleSpread: true,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expect(geo.foldX, greaterThan(geo.spineX));
        expectFlapRegion(flapPath);

        for (final y in [50.0, height / 2, height - 50.0]) {
          verifyOverlap(stationaryPath, flapPath, y);
        }
      });

      test('backward flip — paths aligned at fold boundary', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: false,
          touchOffset: Offset.zero,
          size: size,
          isDoubleSpread: true,
          isForward: false,
        );

        // Backward: flap is RIGHT of foldX. Open clip (right of foldX)
        // shares the fold boundary with the flap; stationary clip is LEFT.
        final openPath = buildOpenPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expectFlapRegion(flapPath);
        for (final y in [50.0, height / 2, height - 50.0]) {
          verifyOverlap(openPath, flapPath, y);
        }
      });
    });

    group('backward flip (single page)', () {
      test('progress=0.5 — fold line alignment holds', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: false,
          touchOffset: Offset.zero,
          size: size,
          isForward: false,
        );

        // Backward: flap is RIGHT of foldX. Open clip (right of foldX)
        // shares the fold boundary with the flap.
        final openPath = buildOpenPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        expectFlapRegion(flapPath);
        verifyOverlap(openPath, flapPath, height / 2);
      });
    });

    group('stationary vs open clip path relationship', () {
      test('open path covers the area right of fold line', () {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
        );

        final openPath = buildOpenPageClipPath(size, geo);
        final stationaryPath = buildStationaryPageClipPath(size, geo);

        // far-left should be only stationary, not open.
        expect(stationaryPath.contains(const Offset(5, 300)), isTrue);
        expect(openPath.contains(const Offset(5, 300)), isFalse);

        // far-right should be in open path, not stationary.
        expect(stationaryPath.contains(const Offset(width - 5, 300)), isFalse);
        expect(openPath.contains(const Offset(width - 5, 300)), isTrue);
      });
    });

    group('snapClipCoord precision', () {
      test('rounds to nearest 0.5', () {
        expect(snapClipCoord(0), equals(0.0));
        expect(snapClipCoord(0.3), equals(0.5));
        expect(snapClipCoord(0.7), equals(0.5));
        expect(snapClipCoord(1), equals(1.0));
        expect(snapClipCoord(1.49), equals(1.5));
        expect(snapClipCoord(1.5), equals(1.5));
        expect(snapClipCoord(1.51), equals(1.5));
        expect(snapClipCoord(2), equals(2.0));
        expect(snapClipCoord(-0.3), equals(-0.5));
        expect(snapClipCoord(-0.7), equals(-0.5));
      });
    });

    group('extreme edge cases', () {
      test('progress=0.25 with extreme touch offset', () {
        final geo = PageFlipGeometry(
          progress: 0.25,
          isRightToLeft: true,
          touchOffset: const Offset(0, 250),
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        if (geo.flapLeft < geo.foldX - 0.5) {
          expectFlapRegion(flapPath);
          verifyOverlap(stationaryPath, flapPath, height / 3);
        }
      });

      test('progress=0.75 with extreme negative touch offset', () {
        final geo = PageFlipGeometry(
          progress: 0.75,
          isRightToLeft: true,
          touchOffset: const Offset(0, -250),
          size: size,
        );

        final stationaryPath = buildStationaryPageClipPath(size, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        if (geo.flapLeft < geo.foldX - 0.5) {
          expectFlapRegion(flapPath);
          verifyOverlap(stationaryPath, flapPath, 2 * height / 3);
        }
      });

      test('small page size (400×800)', () {
        const smallSize = Size(400, 800);
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: smallSize,
        );

        final stationaryPath = buildStationaryPageClipPath(smallSize, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        // Points left of fold should be stationary.
        expect(stationaryPath.contains(const Offset(50, 400)), isTrue);
        if (geo.flapLeft < geo.foldX - 0.5) {
          expectFlapRegion(flapPath);
        }
      });

      test('tall narrow page (300×900)', () {
        const tallSize = Size(300, 900);
        final geo = PageFlipGeometry(
          progress: 0.4,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: tallSize,
        );

        final stationaryPath = buildStationaryPageClipPath(tallSize, geo);
        final flapPath = buildFlapScreenClipPath(geo);

        if (geo.flapLeft < geo.foldX - 0.5) {
          expectFlapRegion(flapPath);
        }
      });
    });
  });
}
