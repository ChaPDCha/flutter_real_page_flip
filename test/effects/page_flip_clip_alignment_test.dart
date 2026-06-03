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
      test('stationary and open fold boundaries overlap by 2× bleed at $progress', () {
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
    test('flap clip uses snapped fold bleed and curves leftward at mid-height', () {
      final g = geo(progress: 0.85);
      final bounds = buildFlapClipPathLocal(g).getBounds();
      expect(bounds.right, snapClipCoord(g.foldX + kSpineRevealOverlapPx));
      // Curved flap extends left of flapLeft because the bezier control
      // point pulls the mid-height edge further left (paper curl).
      expect(bounds.left, lessThan(snapClipCoord(g.flapLeft)));
    });

    test('spine reveal trailing edge matches snapped flap edge + bleed', () {
      final g = geo(progress: 0.92);
      final edges = spineRevealClipEdges(g);
      expect(edges, isNotNull);
      expect(
        edges!.edgeTop,
        snapClipPoint(g.flapEdgeTop, overlapShift: -kSpineRevealOverlapPx),
      );
      expect(
        edges.edgeBottom,
        snapClipPoint(g.flapEdgeBottom, overlapShift: -kSpineRevealOverlapPx),
      );
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

    test('backward mid-flip extends fold past canvas for clean clip', () {
      final g = geo(progress: 0.15, isForward: false);

      expect(g.foldX, greaterThan(g.spineX + 100));
      // With curvature, the bezier fold line extends past canvas width.
      // This is correct — ClipPath at widget bounds ensures clean rendering.
      expect(
        buildOpenPageClipPath(canvasSize, g).getBounds().right,
        greaterThanOrEqualTo(canvasSize.width),
      );
      // Must stay right of spine so it doesn't leak into stationary half.
      expect(
        buildOpenPageClipPath(canvasSize, g).getBounds().left,
        greaterThan(g.spineX),
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
