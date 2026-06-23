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
  }) {
    return PageFlipGeometry(
      progress: progress,
      isRightToLeft: true,
      touchOffset: touchOffset,
      size: canvasSize,
      isDoubleSpread: isDoubleSpread,
      isForward: isForward,
    );
  }

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

        expect(
          statTop.dx - openTop.dx,
          closeTo(kSpineRevealOverlapPx * 2, 0.01),
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
        isForward: true,
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
        isForward: true,
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
}
