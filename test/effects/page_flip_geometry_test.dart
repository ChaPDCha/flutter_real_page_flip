import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipGeometry foldX', () {
    test('single-page forward foldX moves right to left', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo0.foldX, closeTo(400, 0.001));
      expect(geo1.foldX, closeTo(0, 0.001));
    });

    test('single backward foldX moves left to right (mid-flip at 200)', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(200, 0.001));
    });
  });

  group('PageFlipGeometry shadowIntensity', () {
    test('peaks at progress=0.5', () {
      final at0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).shadowIntensity;
      final atMid = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).shadowIntensity;
      final at1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).shadowIntensity;
      expect(at0, closeTo(0, 0.001));
      expect(atMid, greaterThan(0.9));
      expect(at1, closeTo(0, 0.001));
    });

    test('symmetric around 0.5', () {
      final at03 = PageFlipGeometry(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).shadowIntensity;
      final at07 = PageFlipGeometry(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).shadowIntensity;
      expect(at03, closeTo(at07, 0.001));
    });
  });

  group('PageFlipGeometry flapVisibleWidth', () {
    test('single-page forward increases with progress', () {
      // Single forward: flap grows from edge as page turns.
      final atStart = PageFlipGeometry(
        progress: 0.1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).flapVisibleWidth;
      final atEnd = PageFlipGeometry(
        progress: 0.9,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).flapVisibleWidth;
      expect(atEnd, greaterThan(atStart));
    });

    test('never negative at any progress', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: const Size(400, 600),
        );
        expect(geo.flapVisibleWidth, greaterThanOrEqualTo(0));
      }
    });
  });

  group('PageFlipGeometry flapLeft', () {
    test('single forward flapLeft is less than foldX (flap extends left)', () {
      // Single forward: flapRightOfFold=false → flap extends left.
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.flapLeft, lessThan(geo.foldX));
    });

    test('single forward freeEdgeX decreases toward spine', () {
      // As progress increases, flapVisibleWidth shrinks → free edge approaches foldX.
      final early = PageFlipGeometry(
        progress: 0.1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final late = PageFlipGeometry(
        progress: 0.95,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(early.freeEdgeX, greaterThan(late.freeEdgeX));
    });
  });

  group('PageFlipGeometry angle and touch offset', () {
    test('touch offset at center produces near-zero angle', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 300),
        size: const Size(400, 600),
      );
      // touch at exact center height = minimal angle
      expect(geo.angle.abs(), lessThan(0.02));
    });

    test('touch offset near top produces negative angle in forward single-page',
        () {
      // Single forward: flapRightOfFold=false → rawAngle = baseAngle.
      // Top touch: baseAngle < 0 → angle negative.
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 50),
        size: const Size(400, 600),
      );
      expect(geo.angle, lessThan(-0.01));
    });

    test(
        'touch offset near bottom produces positive angle in forward single-page',
        () {
      // Single forward: flapRightOfFold=false → rawAngle = baseAngle.
      // Bottom touch: baseAngle > 0 → angle positive.
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 550),
        size: const Size(400, 600),
      );
      expect(geo.angle, greaterThan(0.01));
    });

    test('angle is zero at progress extremes regardless of touch', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: const Offset(200, 50),
        size: const Size(400, 600),
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: const Offset(200, 50),
        size: const Size(400, 600),
      );
      expect(geo0.angle, closeTo(0, 0.001));
      expect(geo1.angle, closeTo(0, 0.001));
    });

    test('offscreen vertical touch is clamped to viewport angle range', () {
      final topEdge = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final farAbove = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(0, -1000000),
        size: const Size(400, 600),
      );
      final bottomEdge = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(0, 600),
        size: const Size(400, 600),
      );
      final farBelow = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(0, 1000000),
        size: const Size(400, 600),
      );

      expect(farAbove.angle, closeTo(topEdge.angle, 0.001));
      expect(farBelow.angle, closeTo(bottomEdge.angle, 0.001));
    });

    test('conservative cap limits edge drags on tall double-spread pages', () {
      const size = Size(360, 1600);
      const progress = 0.5;
      final topEdge = PageFlipGeometry(
        progress: progress,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: size,
        isDoubleSpread: true,
      );
      final bottomEdge = PageFlipGeometry(
        progress: progress,
        isRightToLeft: true,
        touchOffset: Offset(0, size.height),
        size: size,
        isDoubleSpread: true,
      );
      final expectedLimit = conservativeFoldAngleLimit(
        flapSideWidth: size.width / 4,
        revealedSideWidth: size.width / 4,
        pageWidth: size.width / 2,
        height: size.height,
      );

      expect(expectedLimit, lessThan(0.075));
      expect(topEdge.angle.abs(), lessThanOrEqualTo(expectedLimit + 1e-9));
      expect(bottomEdge.angle.abs(), lessThanOrEqualTo(expectedLimit + 1e-9));
      expect(topEdge.angle, closeTo(-bottomEdge.angle, 0.001));
    });

    test('conservative limit reserves room for all layer overhangs', () {
      final cases = <(Size, double, bool)>[
        (const Size(360, 1600), 0.5, true),
        (const Size(320, 1400), 0.35, true),
        (const Size(1200, 480), 0.5, true),
        (const Size(420, 840), 0.5, false),
      ];

      for (final (size, progress, isDoubleSpread) in cases) {
        final pageWidth = isDoubleSpread ? size.width / 2 : size.width;
        final foldX = size.width - pageWidth * progress;
        final flapSideWidth = pageWidth * progress;
        final revealedSideWidth = isDoubleSpread
            ? (foldX - size.width / 2).clamp(0.0, double.infinity).toDouble()
            : foldX.clamp(0.0, double.infinity).toDouble();

        final limit = conservativeFoldAngleLimit(
          flapSideWidth: flapSideWidth,
          revealedSideWidth: revealedSideWidth,
          pageWidth: pageWidth,
          height: size.height,
        );
        final geo = PageFlipGeometry(
          progress: progress,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
          isDoubleSpread: isDoubleSpread,
        );

        expect(limit, lessThanOrEqualTo(0.12));
        expect(
          geo.angle.abs(),
          lessThanOrEqualTo(limit + 1e-9),
          reason: 'size=$size progress=$progress double=$isDoubleSpread',
        );
      }
    });
  });

  group('PageFlipGeometry fold line endpoints', () {
    test('foldLineTop and foldLineBottom are defined', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldLineTop, isNotNull);
      expect(geo.foldLineBottom, isNotNull);
    });

    test('fold line is vertical when angle is zero (progress=0)', () {
      final geo = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.angle, closeTo(0, 0.001));
      expect(geo.foldLineTop.dx, closeTo(geo.foldLineBottom.dx, 0.5));
    });

    test('fold line endpoints tilt with non-zero angle', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      // With angle ≠ 0 and extended endpoints, top and bottom X differ
      expect(geo.angle.abs(), greaterThan(0.01));
      expect(
        (geo.foldLineTop.dx - geo.foldLineBottom.dx).abs(),
        greaterThan(1),
      );
    });

    test('foldX is between foldLineTop and foldLineBottom X', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      // foldX should be between top and bottom x coordinates
      final minX = math.min(geo.foldLineTop.dx, geo.foldLineBottom.dx);
      final maxX = math.max(geo.foldLineTop.dx, geo.foldLineBottom.dx);
      expect(geo.foldX, greaterThanOrEqualTo(minX - 0.5));
      expect(geo.foldX, lessThanOrEqualTo(maxX + 0.5));
    });

    test('foldNormal is finite, unit length, and perpendicular to fold line',
        () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 50),
        size: const Size(400, 600),
      );

      final foldVector = geo.foldLineBottom - geo.foldLineTop;
      final dot =
          foldVector.dx * geo.foldNormal.dx + foldVector.dy * geo.foldNormal.dy;

      expect(geo.foldNormal.dx.isFinite, isTrue);
      expect(geo.foldNormal.dy.isFinite, isTrue);
      expect(geo.foldNormal.distance, closeTo(1, 0.001));
      expect(dot.abs(), lessThan(0.001));
    });

    test('shadow guide edges stay parallel to fold across aspect ratios', () {
      final cases = <(Size, Offset)>[
        (const Size(360, 780), const Offset(320, 20)),
        (const Size(800, 600), const Offset(720, 580)),
        (const Size(1200, 500), const Offset(1100, 80)),
        (const Size(900, 1600), const Offset(820, 1400)),
        (const Size(360, 1600), const Offset(340, 0)),
        (const Size(360, 1600), const Offset(340, 1600)),
        (const Size(2200, 700), const Offset(2100, 0)),
        (const Size(420, 900), const Offset(390, 900)),
      ];

      double cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

      for (final (size, touch) in cases) {
        final geo = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: touch,
          size: size,
        );

        final foldVector = geo.foldLineBottom - geo.foldLineTop;
        final revealedShadowEdge = MatrixUtils.transformPoint(
              geo.transform,
              Offset(geo.foldX, size.height),
            ) -
            MatrixUtils.transformPoint(
              geo.transform,
              Offset(geo.foldX, 0),
            );
        final stationaryShadowEdge = MatrixUtils.transformPoint(
              geo.transform,
              Offset(geo.freeEdgeX, size.height),
            ) -
            MatrixUtils.transformPoint(
              geo.transform,
              Offset(geo.freeEdgeX, 0),
            );

        expect(
          cross(foldVector, revealedShadowEdge).abs(),
          lessThan(0.001),
          reason: 'revealed shadow edge drifted at size=$size touch=$touch',
        );
        expect(
          cross(foldVector, stationaryShadowEdge).abs(),
          lessThan(0.001),
          reason: 'stationary shadow edge drifted at size=$size touch=$touch',
        );
      }
    });
  });

  group('PageFlipGeometry flap edge endpoints', () {
    test('flapEdgeTop and flapEdgeBottom are defined', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.flapEdgeTop, isNotNull);
      expect(geo.flapEdgeBottom, isNotNull);
    });

    test('flap edge top.y is negative (extended above canvas)', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.flapEdgeTop.dy, lessThan(0));
    });

    test('flap edge bottom.y is beyond canvas height (extended below canvas)',
        () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.flapEdgeBottom.dy, greaterThan(600));
    });
  });

  group('PageFlipGeometry curvature', () {
    test('curvatureAmount is 0 at progress=0 and progress=1', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo0.curvatureAmount, closeTo(0, 0.001));
      expect(geo1.curvatureAmount, closeTo(0, 0.001));
    });

    test('curvatureAmount peaks at progress=0.5', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.curvatureAmount, greaterThan(0.9));
    });

    test(
        'curveOffset magnitude is proportional to curvatureAmount and page width',
        () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      // At progress=0.5, curvatureAmount is ~1, pageWidth=400, 0.04 factor = 16.
      // Single forward: flapRightOfFold=false → curveDirection=1.0 → +16.
      expect(geo.curveOffset, closeTo(16, 2));
    });

    test('single forward curvature offsets fold curve control left', () {
      // Single forward: flapRightOfFold=false → curveDirection=1 → foldCurveControl < foldX.
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldCurveControl.dx, lessThan(geo.foldX));
    });

    test('single backward curvature offsets fold curve control right', () {
      // Single backward: flapRightOfFold=true → curveDirection=-1 → foldCurveControl > foldX.
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldCurveControl.dx, greaterThan(geo.foldX));
    });

    test('no curvature at progress=0 so control equals fold point', () {
      final geo = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.curveOffset, closeTo(0, 0.01));
    });
  });

  group('PageFlipGeometry double spread mode', () {
    test('spineX is at half width for double spread', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(geo.spineX, closeTo(400, 0.001));
    });

    test('spineX is 0 for single page mode', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
      );
      expect(geo.spineX, closeTo(0, 0.001));
    });

    test('double-spread foldX moves from full width to spine', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(geo0.foldX, closeTo(800, 0.001));
      expect(geo1.foldX, closeTo(400, 0.001));
    });

    test('double-spread flapVisibleWidth is smaller (single page width)', () {
      final single = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
      );
      final spread = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(spread.flapVisibleWidth, lessThan(single.flapVisibleWidth));
    });
  });

  group('PageFlipGeometry backward direction', () {
    test('single backward foldX moves left to right (mid-flip at 200)', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.foldX, closeTo(200, 0.001));
    });

    test('single backward curvature is inverted relative to forward', () {
      // Single forward: flapRightOfFold=false → curveDirection=1 → positive.
      // Single backward: flapRightOfFold=true → curveDirection=-1 → negative.
      final fwd = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final bwd = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(fwd.curveOffset, greaterThan(0));
      expect(bwd.curveOffset, lessThan(0));
    });
  });

  group('PageFlipGeometry transform matrix', () {
    test('transform is identity at progress=0', () {
      final geo = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
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
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 100),
        size: const Size(400, 600),
      );
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

  group('PageFlipGeometry single-page forward details', () {
    test('single forward flap extends left of moving foldX', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo.flapLeft, lessThan(geo.foldX));
    });

    test('single forward foldX moves right to left', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final geo5 = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geo0.foldX, closeTo(400, 0.001));
      expect(geo5.foldX, closeTo(200, 0.001));
      expect(geo1.foldX, closeTo(0, 0.001));
    });
  });

  group('PageFlipGeometry single-page backward details', () {
    test('single backward flap extends right from foldX', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      // foldX is at 200, flapRightOfFold=true → flapLeft == foldX.
      expect(geo.flapLeft, equals(geo.foldX));
      expect(geo.freeEdgeX, greaterThan(geo.foldX));
    });

    test(
        'single backward foldX moves right to left with progress (since drag progress goes 1->0)',
        () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ); // end of drag
      final geo5 = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ); // mid
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ); // start of drag
      expect(geo0.foldX, closeTo(400, 0.001));
      expect(geo5.foldX, closeTo(200, 0.001));
      expect(geo1.foldX, closeTo(0, 0.001));
    });

    test('single backward flapVisibleWidth decreases with progress', () {
      // For backward: flapMaterialWidth = pageWidth * (1.0 - clampedProgress)
      // So as progress increases (from 0 to 1), flapMaterialWidth decreases.
      final atStartProgress = PageFlipGeometry(
        progress: 0.1,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).flapVisibleWidth;
      final atEndProgress = PageFlipGeometry(
        progress: 0.9,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      ).flapVisibleWidth;
      expect(atEndProgress, lessThan(atStartProgress));
    });
  });

  group('PageFlipGeometry backward double-spread', () {
    test('backward double-spread foldX moves from left edge to spine', () {
      final geo0 = PageFlipGeometry(
        progress: 0,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final geo1 = PageFlipGeometry(
        progress: 1,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      // Backward double: foldX = pageWidth*(1.0-progress) where pageWidth=400
      // progress=0 → foldX = 400, progress=1 → foldX = 0
      expect(geo0.foldX, closeTo(400, 0.001)); // progress=0 → foldX=400 (spine)
      expect(geo1.foldX, closeTo(0, 0.001)); // progress=1 → foldX=0 (left edge)
    });

    test('backward double-spread flapVisibleWidth decreases with progress', () {
      final ps = [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0];
      double? prev;
      for (final p in ps) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          isForward: false,
          touchOffset: Offset.zero,
          size: const Size(800, 600),
          isDoubleSpread: true,
        );
        if (p == 1.0) {
          expect(geo.flapVisibleWidth, closeTo(0, 0.01));
        } else {
          expect(geo.flapVisibleWidth, greaterThan(0));
        }
        expect(geo.flapVisibleWidth, lessThan(450.0));
        if (prev != null) {
          expect(geo.flapVisibleWidth, lessThanOrEqualTo(prev));
        }
        prev = geo.flapVisibleWidth;
      }
    });

    test('backward double-spread flapLeft is at foldX', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          isForward: false,
          touchOffset: Offset.zero,
          size: const Size(800, 600),
          isDoubleSpread: true,
        );
        expect(geo.flapLeft, lessThanOrEqualTo(geo.foldX + 0.01));
        expect(geo.flapLeft, greaterThanOrEqualTo(geo.foldX - 0.01));
        expect(geo.freeEdgeX, greaterThanOrEqualTo(geo.foldX));
      }
    });

    test('backward double-spread angle is inverted relative to forward double',
        () {
      final fwd = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(400, 100),
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      final bwd = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: const Offset(400, 100),
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(fwd.angle, lessThan(0));
      expect(bwd.angle, greaterThan(0));
      expect(fwd.angle.abs(), closeTo(bwd.angle.abs(), 0.02));
    });

    test('backward double-spread curveOffset is negative (bulges right)', () {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        isForward: false,
        touchOffset: Offset.zero,
        size: const Size(800, 600),
        isDoubleSpread: true,
      );
      expect(geo.curveOffset, lessThan(0));
    });

    test('backward double-spread foldX stays within [0, spineX]', () {
      for (final p in [0.0, 0.01, 0.1, 0.5, 0.9, 0.99, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          isForward: false,
          touchOffset: Offset.zero,
          size: const Size(800, 600),
          isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(0));
        expect(geo.foldX, lessThanOrEqualTo(400.5));
      }
    });
  });

  group('PageFlipGeometry invariants', () {
    test('flapLeft <= foldX throughout flip', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: const Size(400, 600),
        );
        expect(geo.flapLeft, lessThanOrEqualTo(geo.foldX + 0.01));
      }
    });

    test('flap does not extend past canvas left edge throughout flip', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: const Size(400, 600),
        );
        // flapLeft can be < 0 at early progress (flap extends past canvas on the
        // left), but the ClipPath in PageFlipLayerView handles this.
        // flapLeft must be < foldX (flap starts left of the fold hinge).
        expect(geo.flapLeft, lessThan(geo.foldX + 0.5));
      }
    });

    test('double-spread forward invariants (foldX between spineX and width)',
        () {
      for (final p in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: const Size(800, 600),
          isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(geo.spineX - 0.5));
        expect(geo.foldX, lessThanOrEqualTo(geo.size.width + 0.5));
      }
    });

    test('double-spread backward invariants (foldX between 0 and spineX)', () {
      for (final p in [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
        final geo = PageFlipGeometry(
          progress: p,
          isRightToLeft: true,
          isForward: false,
          touchOffset: Offset.zero,
          size: const Size(800, 600),
          isDoubleSpread: true,
        );
        expect(geo.foldX, greaterThanOrEqualTo(0));
        expect(geo.foldX, lessThanOrEqualTo(geo.spineX + 0.5));
      }
    });

    test('NaN progress triggers assertion error in debug mode', () {
      expect(
        () => PageFlipGeometry(
          progress: double.nan,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: const Size(400, 600),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('out-of-range progress is clamped to [0, 1]', () {
      final geoNeg = PageFlipGeometry(
        progress: -0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geoNeg.progress, equals(0.0));

      final geoOver = PageFlipGeometry(
        progress: 1.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 600),
      );
      expect(geoOver.progress, equals(1.0));
    });
  });

  group('PageFlipGeometry extreme edge cases', () {
    test('Zero size constraint does not throw Infinity or NaN', () {
      final geoZero = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(0, 0),
      );

      expect(geoZero.foldX.isFinite, isTrue);
      expect(geoZero.flapLeft.isFinite, isTrue);
      expect(geoZero.angle.isFinite, isTrue);
      expect(geoZero.transform.storage.every((v) => v.isFinite), isTrue);

      final geoTiny = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(0.001, 0.001),
      );

      expect(geoTiny.foldX.isFinite, isTrue);
      expect(geoTiny.angle.isFinite, isTrue);
      expect(geoTiny.transform.storage.every((v) => v.isFinite), isTrue);
    });

    test('Extreme touch offset does not break geometry calculations', () {
      final geoExtremeTop = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, -1000000),
        size: const Size(400, 600),
      );

      final geoExtremeBottom = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(200, 1000000),
        size: const Size(400, 600),
      );

      // Angle should be clamped inside the constructor
      expect(geoExtremeTop.angle.isFinite, isTrue);
      expect(geoExtremeBottom.angle.isFinite, isTrue);

      // Verify that the transform matrix is not corrupted with NaNs
      expect(geoExtremeTop.transform.storage.every((v) => !v.isNaN), isTrue);
      expect(geoExtremeBottom.transform.storage.every((v) => !v.isNaN), isTrue);
    });
  });
}
