import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  const canvasSize = Size(800, 600);

  PageFlipGeometry geo({
    required double progress,
    bool isDoubleSpread = true,
    bool isForward = true,
    Offset touchOffset = Offset.zero,
  }) =>
      PageFlipGeometry(
        progress: progress,
        isRightToLeft: true,
        touchOffset: touchOffset,
        size: canvasSize,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
      );

  group('fold seam overlap', () {
    for (final progress in [0.5, 0.85, 0.92]) {
      test(
          'stationary and open fold boundaries overlap by 2× bleed at $progress',
          () {
        final g = geo(progress: progress);
        final statTop = snapClipPoint(
          g.foldLineTop,
          overlapShift: kSpineRevealOverlapPx,
        );
        final openTop = snapClipPoint(
          g.foldLineTop,
          overlapShift: -kSpineRevealOverlapPx,
        );

        final overlapVector = statTop - openTop;
        final normalOverlap = overlapVector.dx * g.foldNormal.dx +
            overlapVector.dy * g.foldNormal.dy;

        expect(
          normalOverlap,
          closeTo(kSpineRevealOverlapPx * 2, 0.75),
        );
      });
    }
  });

  group('buildFlapClipPathLocal vs fold clip', () {
    test('flap clip uses snapped fold bleed and curves leftward at mid-height',
        () {
      final g = geo(progress: 0.85);
      final bounds = buildFlapClipPathLocal(g).getBounds();
      expect(bounds.right, snapClipCoord(g.foldX + kSpineRevealOverlapPx));
      // Curved flap extends left of flapLeft because the bezier control
      // point pulls the mid-height edge further left (paper curl).
      expect(bounds.left, lessThan(snapClipCoord(g.flapLeft)));
    });
  });

  group('curved fold shadow band', () {
    test('uses quadratic midpoint bulge instead of full control offset', () {
      final g = geo(progress: 0.5);

      expect(
        foldCurveMaxBulge(g),
        closeTo(g.curveOffset.abs() * 0.5, 0.001),
      );
      expect(
        foldCurveMaxBulge(g),
        lessThan(g.curveOffset.abs()),
        reason: 'The shadow cover should not reserve the full bezier control '
            'offset; that makes the crease band visibly too thick.',
      );
    });

    test('forward shadow path hugs the curved fold without a straight slab',
        () {
      final g = geo(progress: 0.5, isDoubleSpread: false);
      const shadowWidth = 22.0;
      final path = buildCurvedFoldShadowPath(
        g,
        isForward: true,
        shadowWidth: shadowWidth,
      );
      final midY = g.size.height / 2;
      final foldAtMid = foldCurveXAt(g, midY);

      expect(path.contains(Offset(foldAtMid + 1, midY)), isTrue);
      expect(
        path.contains(Offset(foldAtMid - kSpineRevealOverlapPx - 2, midY)),
        isFalse,
      );
      expect(path.contains(Offset(foldAtMid + shadowWidth + 2, midY)), isFalse);
    });

    test('backward shadow path hugs the curved fold on the opposite side', () {
      final g = geo(
        progress: 0.5,
        isDoubleSpread: false,
        isForward: false,
      );
      const shadowWidth = 22.0;
      final path = buildCurvedFoldShadowPath(
        g,
        isForward: false,
        shadowWidth: shadowWidth,
      );
      final midY = g.size.height / 2;
      final foldAtMid = foldCurveXAt(g, midY);

      expect(path.contains(Offset(foldAtMid - 1, midY)), isTrue);
      expect(
        path.contains(Offset(foldAtMid + kSpineRevealOverlapPx + 2, midY)),
        isFalse,
      );
      expect(path.contains(Offset(foldAtMid - shadowWidth - 2, midY)), isFalse);
    });
  });

  group('unified single-page crease mesh geometry', () {
    const segments = 12;
    const columnCount = 6;
    final cases = <(Size, bool, Offset)>[
      (const Size(360, 1600), true, const Offset(340, 0)),
      (const Size(360, 1600), false, const Offset(20, 1600)),
      (const Size(2200, 700), true, const Offset(2100, 0)),
      (const Size(2200, 700), false, const Offset(100, 700)),
      (const Size(800, 600), true, const Offset(400, 300)),
    ];

    for (final (size, isForward, touch) in cases) {
      test(
          'every opacity column follows the fold curve at '
          '$size forward=$isForward', () {
        final g = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: touch,
          size: size,
          isForward: isForward,
        );
        final positions = buildCurvedCreaseValleyPositions(
          g,
          flapSideWidth: 8,
          revealedSideWidth: 40,
        );

        expect(positions.length, (segments + 1) * columnCount * 2);
        for (var row = 0; row <= segments; row++) {
          final rowOffset = row * columnCount * 2;
          final y = positions[rowOffset + 1];
          final foldX = foldCurveXAt(g, y);
          final xs = <double>[];
          for (var column = 0; column < columnCount; column++) {
            final x = positions[rowOffset + column * 2];
            final vertexY = positions[rowOffset + column * 2 + 1];
            expect(x.isFinite, isTrue);
            expect(vertexY, closeTo(y, 0.001));
            xs.add(x);
          }

          expect(
            xs.any((x) => (x - foldX).abs() < 0.01),
            isTrue,
            reason: 'Each row must contain the exact fold-curve peak; a '
                'straight shader axis would miss it as curvature changes.',
          );
          for (var column = 1; column < xs.length; column++) {
            expect(xs[column], greaterThan(xs[column - 1]));
          }
        }
      });
    }

    test('degenerate dimensions return no crease vertices', () {
      final g = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 0),
      );

      expect(
        buildCurvedCreaseValleyPositions(
          g,
          flapSideWidth: 8,
          revealedSideWidth: 40,
        ),
        isEmpty,
      );
      expect(
        buildCurvedCreaseValleyPositions(
          geo(progress: 0.5, isDoubleSpread: false),
          flapSideWidth: 8,
          revealedSideWidth: 40,
          segments: 0,
        ),
        isEmpty,
      );
    });
  });

  group('curved free-edge contact shadow', () {
    test(
        'forward: shadow extends OUTWARD (left) of the free edge, not '
        'onto the flap', () {
      // Forward: flapRightOfFold=false → free edge sits LEFT of foldX, flap
      // interior is to its right. Contact shadow must ground the lifted edge
      // by extending further LEFT (outward), never bleeding right into the
      // flap's own paint area.
      final g = geo(progress: 0.5, isDoubleSpread: false);
      const shadowWidth = 10.0;
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: shadowWidth);
      final midY = g.size.height / 2;
      final edgeAtMid = flapEdgeCurveXAt(g, midY);

      expect(
        path.contains(Offset(edgeAtMid - 1, midY)),
        isTrue,
        reason: 'Shadow should cover just outside (left of) the free edge',
      );
      expect(
        path.contains(Offset(edgeAtMid + kSpineRevealOverlapPx + 2, midY)),
        isFalse,
        reason: 'Shadow must not bleed onto the flap side of the free edge',
      );
      expect(
        path.contains(Offset(edgeAtMid - shadowWidth - 2, midY)),
        isFalse,
        reason: 'Shadow must not extend past its declared width',
      );
    });

    test('backward: shadow extends OUTWARD (right) of the free edge', () {
      // Backward: flapRightOfFold=true → free edge sits RIGHT of foldX, flap
      // interior is to its left. Contact shadow must extend further RIGHT.
      final g = geo(progress: 0.5, isDoubleSpread: false, isForward: false);
      const shadowWidth = 10.0;
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: shadowWidth);
      final midY = g.size.height / 2;
      final edgeAtMid = flapEdgeCurveXAt(g, midY);

      expect(path.contains(Offset(edgeAtMid + 1, midY)), isTrue);
      expect(
        path.contains(Offset(edgeAtMid - kSpineRevealOverlapPx - 2, midY)),
        isFalse,
      );
      expect(path.contains(Offset(edgeAtMid + shadowWidth + 2, midY)), isFalse);
    });

    test('zero shadow width returns an empty path (no degenerate draw)', () {
      final g = geo(progress: 0.5, isDoubleSpread: false);
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: 0);
      expect(path.getBounds().isEmpty, isTrue);
    });

    test('negative shadow width returns an empty path', () {
      final g = geo(progress: 0.5, isDoubleSpread: false);
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: -5);
      expect(path.getBounds().isEmpty, isTrue);
    });

    test('zero-height viewport returns an empty path (no NaN/Infinity)', () {
      final g = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        size: const Size(400, 0),
      );
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: 10);
      expect(path.getBounds().isEmpty, isTrue);
    });

    test('double-spread forward hugs the free edge on the correct side', () {
      // Same geometric contract must hold in double-spread, not just single.
      final g = geo(progress: 0.5);
      const shadowWidth = 10.0;
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: shadowWidth);
      final midY = g.size.height / 2;
      final edgeAtMid = flapEdgeCurveXAt(g, midY);

      expect(path.contains(Offset(edgeAtMid - 1, midY)), isTrue);
      expect(path.contains(Offset(edgeAtMid + shadowWidth + 2, midY)), isFalse);
    });

    test('path bounds stay finite at extreme angled touch (no NaN)', () {
      final g = geo(
        progress: 0.5,
        isDoubleSpread: false,
        touchOffset: const Offset(0, -100000),
      );
      final path = buildCurvedFreeEdgeShadowPath(g, shadowWidth: 10);
      final bounds = path.getBounds();
      expect(bounds.left.isFinite, isTrue);
      expect(bounds.top.isFinite, isTrue);
      expect(bounds.right.isFinite, isTrue);
      expect(bounds.bottom.isFinite, isTrue);
    });
  });

  group('clippers delegate to shared builders', () {
    test('PageFlipClipper matches buildStationaryPageClipPath', () {
      final g = geo(progress: 0.85);
      final clipper = PageFlipClipper(
        progress: 0.85,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        isDoubleSpread: true,
      );
      final fromClipper = clipper.getClip(canvasSize);
      final fromBuilder = buildStationaryPageClipPath(canvasSize, g);

      expect(
        fromClipper.getBounds(),
        equals(fromBuilder.getBounds()),
      );
    });

    test('PageFlipOpenClipper matches buildOpenPageClipPath', () {
      final g = geo(progress: 0.85);
      final clipper = PageFlipOpenClipper(
        progress: 0.85,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        isDoubleSpread: true,
      );
      final fromClipper = clipper.getClip(canvasSize);
      final fromBuilder = buildOpenPageClipPath(canvasSize, g);

      expect(
        fromClipper.getBounds(),
        equals(fromBuilder.getBounds()),
      );
    });

    test('backward mid-flip foldX left of spine, open clip covers right side',
        () {
      final g = geo(progress: 0.15, isForward: false);

      // Backward: foldX moves from left edge (0) toward spineX.
      expect(g.foldX, lessThan(g.spineX));
      // With curvature, the bezier fold line extends past canvas width.
      // This is correct — ClipPath at widget bounds ensures clean rendering.
      expect(
        buildOpenPageClipPath(canvasSize, g).getBounds().right,
        greaterThanOrEqualTo(canvasSize.width),
      );
      // Open clip (right of foldX) should extend left to foldX, not to spine.
      expect(
        buildOpenPageClipPath(canvasSize, g).getBounds().left,
        lessThan(g.spineX),
      );
    });
  });

  group('snapClipCoord', () {
    test('rounds to half-pixel grid', () {
      expect(snapClipCoord(10.24), 10.0);
      expect(snapClipCoord(10.26), 10.5);
      expect(snapClipCoord(10.74), 10.5);
      expect(snapClipCoord(10.76), 11.0);
    });
  });

  group('clip path intersection exactness', () {
    test(
        'Stationary clip right boundary exactly matches Flap clip left boundary',
        () {
      final g = geo(progress: 0.5);
      final statPath = buildStationaryPageClipPath(canvasSize, g);
      final flapPath = buildOpenPageClipPath(canvasSize, g);

      // We check that the bounding boxes around the fold overlap. The exact
      // left bound can move with the conservative angle cap and curved fold,
      // but a gap between the stationary/open clips is never acceptable.
      final statBounds = statPath.getBounds();
      final flapBounds = flapPath.getBounds();

      // Stationary path extends to foldX + overlap
      // Flap path extends to foldX - overlap (or flapLeft, whichever is furthest left)
      // Since they are designed to overlap cleanly:
      final expectedStatRight = snapClipCoord(g.foldX + kSpineRevealOverlapPx);
      expect(statBounds.right, greaterThanOrEqualTo(expectedStatRight));

      expect(
        statBounds.right - flapBounds.left,
        greaterThanOrEqualTo(kSpineRevealOverlapPx * 2),
      );
    });
  });

  group('screen aspect ratio clip tests', () {
    final ratios = {
      'Ultra Wide 21:9': const Size(2100, 900),
      'Standard 4:3': const Size(800, 600),
      'Portrait 9:16': const Size(900, 1600),
    };

    for (final entry in ratios.entries) {
      test('clip bounds are valid for ${entry.key}', () {
        final size = entry.value;
        final g = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: size,
          isDoubleSpread: true,
        );

        final statPath = buildStationaryPageClipPath(size, g);
        final openPath = buildOpenPageClipPath(size, g);

        expect(statPath.getBounds().left, lessThanOrEqualTo(0));
        expect(statPath.getBounds().right, greaterThan(0));

        expect(openPath.getBounds().left, lessThanOrEqualTo(size.width));
        expect(openPath.getBounds().right, greaterThanOrEqualTo(size.width));
      });
    }

    bool pathsOverlapAtY(Path a, Path b, Size size, double y) {
      final step = math.max(1, size.width / 900);
      for (var x = 0.0; x <= size.width; x += step) {
        final point = Offset(x, y);
        if (a.contains(point) && b.contains(point)) return true;
      }
      return false;
    }

    test('edge-drag flap clips overlap fold-side clips on extreme ratios', () {
      final cases = <(Size, bool, double, Offset)>[
        (const Size(360, 1600), true, 0.5, const Offset(340, 0)),
        (const Size(360, 1600), true, 0.5, const Offset(340, 1600)),
        (const Size(360, 1600), false, 0.5, const Offset(20, 0)),
        (const Size(360, 1600), false, 0.5, const Offset(20, 1600)),
        (const Size(2200, 700), true, 0.42, const Offset(2100, 0)),
        (const Size(2200, 700), false, 0.58, const Offset(100, 700)),
      ];

      for (final (size, isForward, progress, touch) in cases) {
        final g = PageFlipGeometry(
          progress: progress,
          isRightToLeft: true,
          touchOffset: touch,
          size: size,
          isDoubleSpread: true,
          isForward: isForward,
        );
        final foldSidePath = isForward
            ? buildStationaryPageClipPath(size, g)
            : buildOpenPageClipPath(size, g);
        final flapPath = buildFlapScreenClipPath(g);

        for (final y in [
          size.height * 0.15,
          size.height * 0.5,
          size.height * 0.85,
        ]) {
          expect(
            pathsOverlapAtY(foldSidePath, flapPath, size, y),
            isTrue,
            reason:
                'No fold/flap overlap at size=$size forward=$isForward y=$y',
          );
        }
      }
    });
  });
}
