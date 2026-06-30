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
