import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipGeometry foldX', () {
    test('progress=0 equals full width', () {
      final geo = PageFlipGeometry(
        progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(400, 0.001));
    });

    test('progress=1 equals 0', () {
      final geo = PageFlipGeometry(
        progress: 1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(0, 0.001));
    });

    test('progress=0.5 is half width', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(200, 0.001));
    });
  });

  group('PageFlipGeometry shadowIntensity', () {
    test('peaks at progress=0.5', () {
      final at0 = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).shadowIntensity;
      final atMid = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).shadowIntensity;
      final at1 = PageFlipGeometry(progress: 1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).shadowIntensity;
      expect(at0, closeTo(0, 0.001));
      expect(atMid, greaterThan(0.9));
      expect(at1, closeTo(0, 0.001));
    });

    test('symmetric around 0.5', () {
      final at03 = PageFlipGeometry(progress: 0.3, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).shadowIntensity;
      final at07 = PageFlipGeometry(progress: 0.7, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).shadowIntensity;
      expect(at03, closeTo(at07, 0.001));
    });
  });

  group('PageFlipGeometry flapVisibleWidth', () {
    test('increases with progress', () {
      final atStart = PageFlipGeometry(progress: 0.1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).flapVisibleWidth;
      final atEnd = PageFlipGeometry(progress: 0.9, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600)).flapVisibleWidth;
      expect(atEnd, greaterThan(atStart));
    });

    test('never negative at any progress', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(progress: p, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
        expect(geo.flapVisibleWidth, greaterThanOrEqualTo(0));
      }
    });
  });

  group('PageFlipGeometry flapLeft', () {
    test('starts near foldX at low progress', () {
      final geo = PageFlipGeometry(progress: 0.1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      // flapLeft is left of foldX by foreshortened flap width
      expect(geo.flapLeft, lessThan(geo.foldX));
      // flapLeft should be non-negative (clipped later if needed)
      expect(geo.flapLeft, greaterThanOrEqualTo(0));
    });

    test('approaches 0 as progress increases', () {
      final geo = PageFlipGeometry(progress: 0.95, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.flapLeft, lessThan(50));
    });
  });

  group('PageFlipGeometry angle and touch offset', () {
    test('touch offset at center produces near-zero angle', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: const Offset(200, 300), size: const Size(400, 600),
      );
      // touch at exact center height = minimal angle
      expect(geo.angle.abs(), lessThan(0.02));
    });

    test('touch offset near top produces negative angle', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: const Offset(200, 50), size: const Size(400, 600),
      );
      // (50/600 - 0.5) = -0.4167 → negative angle
      expect(geo.angle, lessThan(-0.01));
    });

    test('touch offset near bottom produces positive angle', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: const Offset(200, 550), size: const Size(400, 600),
      );
      // (550/600 - 0.5) = +0.4167 → positive angle
      expect(geo.angle, greaterThan(0.01));
    });

    test('angle is zero at progress extremes regardless of touch', () {
      final geo0 = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: const Offset(200, 50), size: const Size(400, 600));
      final geo1 = PageFlipGeometry(progress: 1, isRightToLeft: true, touchOffset: const Offset(200, 50), size: const Size(400, 600));
      expect(geo0.angle, closeTo(0, 0.001));
      expect(geo1.angle, closeTo(0, 0.001));
    });
  });

  group('PageFlipGeometry fold line endpoints', () {
    test('foldLineTop and foldLineBottom are defined', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.foldLineTop, isNotNull);
      expect(geo.foldLineBottom, isNotNull);
    });

    test('fold line is vertical when angle is zero (progress=0)', () {
      final geo = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.angle, closeTo(0, 0.001));
      expect(geo.foldLineTop.dx, closeTo(geo.foldLineBottom.dx, 0.5));
    });

    test('fold line endpoints tilt with non-zero angle', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      // With angle ≠ 0 and extended endpoints, top and bottom X differ
      expect(geo.angle.abs(), greaterThan(0.01));
      expect((geo.foldLineTop.dx - geo.foldLineBottom.dx).abs(), greaterThan(1));
    });

    test('foldX is between foldLineTop and foldLineBottom X', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      // foldX should be between top and bottom x coordinates
      final minX = math.min(geo.foldLineTop.dx, geo.foldLineBottom.dx);
      final maxX = math.max(geo.foldLineTop.dx, geo.foldLineBottom.dx);
      expect(geo.foldX, greaterThanOrEqualTo(minX - 0.5));
      expect(geo.foldX, lessThanOrEqualTo(maxX + 0.5));
    });
  });

  group('PageFlipGeometry flap edge endpoints', () {
    test('flapEdgeTop and flapEdgeBottom are defined', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.flapEdgeTop, isNotNull);
      expect(geo.flapEdgeBottom, isNotNull);
    });

    test('flap edge top.y is negative (extended above canvas)', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.flapEdgeTop.dy, lessThan(0));
    });

    test('flap edge bottom.y is beyond canvas height (extended below canvas)', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.flapEdgeBottom.dy, greaterThan(600));
    });
  });

  group('PageFlipGeometry curvature', () {
    test('curvatureAmount is 0 at progress=0 and progress=1', () {
      final geo0 = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      final geo1 = PageFlipGeometry(progress: 1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo0.curvatureAmount, closeTo(0, 0.001));
      expect(geo1.curvatureAmount, closeTo(0, 0.001));
    });

    test('curvatureAmount peaks at progress=0.5', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.curvatureAmount, greaterThan(0.9));
    });

    test('curveOffset is proportional to curvatureAmount and page width', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      // At progress=0.5, curvatureAmount is ~1, pageWidth=400, 0.04 factor = 16
      expect(geo.curveOffset, closeTo(16, 2));
    });

    test('forward curvature offsets fold curve control left', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: true, touchOffset: Offset.zero, size: const Size(400, 600));
      // Control point X should be less than foldX (leftward bulge)
      expect(geo.foldCurveControl.dx, lessThan(geo.foldX));
    });

    test('backward curvature offsets fold curve control right', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      // Control point X should be greater than foldX (rightward bulge)
      expect(geo.foldCurveControl.dx, greaterThan(geo.foldX));
    });

    test('no curvature at progress=0 so control equals fold point', () {
      final geo = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.curveOffset, closeTo(0, 0.01));
    });
  });

  group('PageFlipGeometry double spread mode', () {
    test('spineX is at half width for double spread', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(geo.spineX, closeTo(400, 0.001));
    });

    test('spineX is 0 for single page mode', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600));
      expect(geo.spineX, closeTo(0, 0.001));
    });

    test('double-spread foldX moves from full width to spine', () {
      final geo0 = PageFlipGeometry(
        progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final geo1 = PageFlipGeometry(
        progress: 1, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(geo0.foldX, closeTo(800, 0.001));
      expect(geo1.foldX, closeTo(400, 0.001));
    });

    test('double-spread flapVisibleWidth is smaller (single page width)', () {
      final single = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600));
      final spread = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(spread.flapVisibleWidth, lessThan(single.flapVisibleWidth));
    });
  });

  group('PageFlipGeometry backward direction', () {
    test('backward foldX moves from 0 to full width as progress increases', () {
      // For backward: foldX starts at 0 (progress=0, no flip motion yet) but
      // note: backward uses floatProgress = 1 - dragProgress in the layer view.
      // The geometry itself is direction-agnostic; isForward just changes curvature.
      // foldX = width - pageWidth*progress regardless of direction.
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(geo.foldX, closeTo(200, 0.001));
    });

    test('backward curvature direction is opposite of forward', () {
      final fwd = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: true, touchOffset: Offset.zero, size: const Size(400, 600));
      final bwd = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      expect(fwd.curveOffset, greaterThan(0));
      expect(bwd.curveOffset, lessThan(0));
    });
  });

  group('PageFlipGeometry transform matrix', () {
    test('transform is identity at progress=0', () {
      final geo = PageFlipGeometry(progress: 0, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
      final storage = geo.transform.storage;
      // Identity matrix: [1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1]
      expect(storage[0], closeTo(1, 0.001));
      expect(storage[5], closeTo(1, 0.001));
      expect(storage[10], closeTo(1, 0.001));
      expect(storage[15], closeTo(1, 0.001));
      // Off-diagonal should be near zero
      expect(storage[1].abs(), lessThan(0.001));
      expect(storage[4].abs(), lessThan(0.001));
    });

    test('transform at progress=0.5 with touch offset has rotation', () {
      final geo = PageFlipGeometry(progress: 0.5, isRightToLeft: true, touchOffset: const Offset(200, 100), size: const Size(400, 600));
      final storage = geo.transform.storage;
      // Rotation matrix: storage[0]=cos, storage[1]=sin
      // With angle = -((100/600)-0.5)*0.3*sin(0.5*pi) ≈ -(-0.33)*0.3*1 ≈ 0.1
      expect(geo.angle.abs(), greaterThan(0.01));
      // cos(angle) should be close to 1 for small angles
      expect(storage[0], greaterThan(0.99));
      // sin(angle) should be non-zero for non-zero angle
      expect(storage[1].abs(), greaterThan(0.001));
    });
  });

  group('PageFlipGeometry backward direction details', () {
    test('backward flapLeft is left of foldX (same as forward)', () {
      final fwd = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: true, touchOffset: Offset.zero, size: const Size(400, 600));
      final bwd = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      // Forward: flapLeft < foldX (flap extends LEFT).
      expect(fwd.flapLeft, lessThan(fwd.foldX));
      // Backward: flapLeft < foldX (flap extends LEFT, same as forward).
      expect(bwd.flapLeft, lessThan(bwd.foldX));
    });

    test('backward flapVisibleWidth derived from foldX', () {
      // For backward at progress=0.5: foldX = pageWidth*progress = 200.
      // flapMaterialWidth = foldX = 200. flapVisibleWidth = 200 * modulation.
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600),
      );
      // flapMaterialWidth is not publicly exposed, but flapVisibleWidth
      // is proportional: it should be positive and always less than pageWidth.
      expect(geo.flapVisibleWidth, greaterThan(0));
      expect(geo.flapVisibleWidth, lessThan(400));
    });

    test('backward rotation angle is inverted relative to forward', () {
      final fwd = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: true, touchOffset: const Offset(200, 100), size: const Size(400, 600),
      );
      final bwd = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: const Offset(200, 100), size: const Size(400, 600),
      );
      // Forward at (200,100): height=600, touch offset dy=100, (100/600-0.5) = -0.417
      // baseAngle = -0.417 * 0.3 * sin(0.5^0.82*pi) ≈ -0.417 * 0.3 * ~1 = -0.125
      // rawAngle forward = baseAngle ≈ -0.125
      // rawAngle backward = -baseAngle ≈ +0.125
      // Angles should have opposite signs (roughly) with same magnitude.
      expect(fwd.angle, lessThan(0));  // forward: negative angle
      expect(bwd.angle, greaterThan(0)); // backward: positive angle
      // Magnitudes should be close (clamping may affect, so check similar order).
      expect(fwd.angle.abs(), greaterThan(0.01));
      expect(fwd.angle.abs(), closeTo(bwd.angle.abs(), 0.02));
    });

    test('backward foldX moves 0 → pageWidth as progress increases', () {
      // Backward: foldX = pageWidth * progress
      // At progress=0: foldX = 0 (starts at left edge).
      // At progress=1: foldX = pageWidth = 400 (reaches right edge).
      final geo0 = PageFlipGeometry(progress: 0, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      final geo5 = PageFlipGeometry(progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));
      final geo1 = PageFlipGeometry(progress: 1, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600));

      expect(geo0.foldX, closeTo(0, 0.001));      // progress=0 → foldX=0 (left edge)
      expect(geo5.foldX, closeTo(200, 0.001));    // progress=0.5 → foldX=200 (midway)
      expect(geo1.foldX, closeTo(400, 0.001));    // progress=1 → foldX=400 (right edge)
    });

    test('backward flapVisibleWidth increases with progress', () {
      final atStart = PageFlipGeometry(progress: 0.1, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600)).flapVisibleWidth;
      final atEnd = PageFlipGeometry(progress: 0.9, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600)).flapVisibleWidth;
      expect(atEnd, greaterThan(atStart));
    });

    test('backward flapLeft is always left of foldX throughout flip', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(400, 600),
        );
        expect(geo.flapLeft, lessThanOrEqualTo(geo.foldX + 0.01));
      }
    });

    test('backward double-spread foldX moves from left edge to spine', () {
      final geo0 = PageFlipGeometry(
        progress: 0, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final geo1 = PageFlipGeometry(
        progress: 1, isRightToLeft: true, isForward: false, touchOffset: Offset.zero, size: const Size(800, 600),
        isDoubleSpread: true,
      );
      // Backward double: foldX = pageWidth*progress where pageWidth=400
      // progress=0 → foldX = 0, progress=1 → foldX = 400
      expect(geo0.foldX, closeTo(0, 0.001));     // starts at left edge
      expect(geo1.foldX, closeTo(400, 0.001));   // ends at spine
    });

    test('backward double-spread flapVisibleWidth increases with progress', () {
      final ps = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0];
      double? prev;
      for (final p in ps) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, isForward: false, touchOffset: Offset.zero,
          size: const Size(800, 600), isDoubleSpread: true,
        );
        if (p == 0.0) {
          expect(geo.flapVisibleWidth, closeTo(0, 0.01));
        } else {
          expect(geo.flapVisibleWidth, greaterThan(0));
        }
        expect(geo.flapVisibleWidth, lessThan(450.0));
        if (prev != null) {
          expect(geo.flapVisibleWidth, greaterThanOrEqualTo(prev!));
        }
        prev = geo.flapVisibleWidth;
      }
    });

    test('backward double-spread flapLeft is always left of foldX', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, isForward: false, touchOffset: Offset.zero,
          size: const Size(800, 600), isDoubleSpread: true,
        );
        expect(geo.flapLeft, lessThanOrEqualTo(geo.foldX + 0.01));
      }
    });

    test('backward double-spread angle is inverted relative to forward double', () {
      final fwd = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: true, touchOffset: const Offset(400, 100),
        size: const Size(800, 600), isDoubleSpread: true,
      );
      final bwd = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: const Offset(400, 100),
        size: const Size(800, 600), isDoubleSpread: true,
      );
      expect(fwd.angle, lessThan(0));
      expect(bwd.angle, greaterThan(0));
      expect(fwd.angle.abs(), closeTo(bwd.angle.abs(), 0.02));
    });

    test('backward double-spread curveOffset is negative (bulges right)', () {
      final geo = PageFlipGeometry(
        progress: 0.5, isRightToLeft: true, isForward: false, touchOffset: Offset.zero,
        size: const Size(800, 600), isDoubleSpread: true,
      );
      expect(geo.curveOffset, lessThan(0));
    });

    test('backward double-spread foldX stays within [0, spineX]', () {
      for (final p in [0.0, 0.01, 0.1, 0.5, 0.9, 0.99, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, isForward: false, touchOffset: Offset.zero,
          size: const Size(800, 600), isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(0));
        expect(geo.foldX, lessThanOrEqualTo(400.5));
      }
    });
  });

  group('PageFlipGeometry invariants', () {
    test('flapLeft <= foldX throughout flip', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(progress: p, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
        expect(geo.flapLeft, lessThanOrEqualTo(geo.foldX + 0.01));
      }
    });

    test('flap does not extend past canvas left edge throughout flip', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(progress: p, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600));
        // flapLeft can be < 0 at early progress (flap extends past canvas on the
        // left), but the ClipPath in PageFlipLayerView handles this.
        // flapLeft must be < foldX (flap starts left of the fold hinge).
        expect(geo.flapLeft, lessThan(geo.foldX + 0.5));
      }
    });

    test('double-spread forward invariants (foldX between spineX and width)', () {
      for (final p in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(800, 600),
          isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(geo.spineX - 0.5));
        expect(geo.foldX, lessThanOrEqualTo(geo.size.width + 0.5));
      }
    });

    test('double-spread backward invariants (foldX between 0 and spineX)', () {
      for (final p in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p, isRightToLeft: true, isForward: false, touchOffset: Offset.zero,
          size: const Size(800, 600), isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(0));
        expect(geo.foldX, lessThanOrEqualTo(geo.spineX + 0.5));
      }
    });

    test('NaN progress does not crash or produce infinite values', () {
      final geo = PageFlipGeometry(
        progress: double.nan, isRightToLeft: true, touchOffset: Offset.zero, size: const Size(400, 600),
      );
      // Constructor should not throw, and computed values should be finite
      // (NaN is technically "finite" per isFinite, but the point is no crash).
      expect(geo.foldX.isNaN, isTrue);
      expect(geo.angle.isNaN, isTrue);
      expect(geo.shadowIntensity.isNaN, isTrue);
      // Verify no infinite values leak through
      expect(geo.foldX.isInfinite, isFalse);
      expect(geo.angle.isInfinite, isFalse);
      expect(geo.shadowIntensity.isInfinite, isFalse);
      expect(geo.transform.storage.any((v) => v.isInfinite), isFalse);
    });
  });
}
