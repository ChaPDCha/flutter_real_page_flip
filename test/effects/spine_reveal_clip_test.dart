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

  group('buildDoubleSpreadSpineRevealPath', () {
    test('returns null before flap crosses spine', () {
      final path = buildDoubleSpreadSpineRevealPath(geo(progress: 0.2));
      expect(path, isNull);
    });

    test('returns null for single-page mode', () {
      final path = buildDoubleSpreadSpineRevealPath(
        geo(progress: 0.9, isDoubleSpread: false),
      );
      expect(path, isNull);
    });

    test('returns null for backward flip before flap crosses spine', () {
      final path = buildDoubleSpreadSpineRevealPath(
        geo(progress: 0.99, isForward: false),
      );
      expect(path, isNull);
    });

    test('returns non-empty path for backward flip after flap crosses spine', () {
      final g = geo(progress: 0.15, isForward: false);
      expect(g.flapLeft, greaterThan(g.spineX));

      final path = buildDoubleSpreadSpineRevealPath(g);
      expect(path, isNotNull);
      expect(path!.getBounds().width, greaterThan(0));
      expect(path.getBounds().left, greaterThanOrEqualTo(g.spineX - 1));
    });

    test('backward reveal band grows as progress decreases past spine crossing', () {
      final narrow = buildDoubleSpreadSpineRevealPath(
        geo(progress: 0.35, isForward: false),
      );
      final wide = buildDoubleSpreadSpineRevealPath(
        geo(progress: 0.15, isForward: false),
      );
      expect(narrow, isNotNull);
      expect(wide, isNotNull);
      expect(
        wide!.getBounds().width,
        greaterThan(narrow!.getBounds().width),
      );
    });

    test('returns non-empty path after flap crosses spine', () {
      final g = geo(progress: 0.92);
      expect(g.flapLeft, lessThan(g.spineX));

      final path = buildDoubleSpreadSpineRevealPath(g);
      expect(path, isNotNull);
      expect(path!.getBounds().width, greaterThan(0));
      expect(path.getBounds().right, lessThanOrEqualTo(g.spineX + 1));
    });

    test('reveal band grows as progress increases past spine crossing', () {
      final early = buildDoubleSpreadSpineRevealPath(geo(progress: 0.82));
      final late = buildDoubleSpreadSpineRevealPath(geo(progress: 0.95));
      expect(early, isNotNull);
      expect(late, isNotNull);
      expect(
        late!.getBounds().width,
        greaterThan(early!.getBounds().width),
      );
    });
  });

  group('spineRevealClipEdges', () {
    test('forward edges use negative overlap shift', () {
      final edges = spineRevealClipEdges(geo(progress: 0.92));
      expect(edges, isNotNull);
      expect(edges!.overlapShift, kSpineRevealOverlapPx * -1);
    });

    test('backward edges use positive overlap shift', () {
      final edges = spineRevealClipEdges(geo(progress: 0.15, isForward: false));
      expect(edges, isNotNull);
      expect(edges!.overlapShift, kSpineRevealOverlapPx);
    });
  });

  group('flipSideShadowClipRect', () {
    test('double spread clips to right half', () {
      final g = geo(progress: 0.5);
      final rect = flipSideShadowClipRect(g);
      expect(rect.left, equals(g.spineX));
      expect(rect.width, equals(canvasSize.width - g.spineX));
      expect(rect.height, equals(canvasSize.height));
    });

    test('single page clips to region right of fold', () {
      final g = geo(progress: 0.5, isDoubleSpread: false);
      final rect = flipSideShadowClipRect(g);
      expect(rect.left, equals(g.foldX));
      expect(rect.width, closeTo(canvasSize.width - g.foldX, 0.01));
      expect(rect.height, equals(canvasSize.height));
    });

    test('single page clip excludes stationary middle layer at high progress', () {
      final g = geo(progress: 0.9, isDoubleSpread: false);
      final rect = flipSideShadowClipRect(g);
      expect(rect.left, greaterThan(0));
      expect(rect.left, equals(g.foldX));
    });

    test('forward and backward single-page shadow clips start at foldX', () {
      final forwardGeo =
          geo(progress: 0.85, isDoubleSpread: false, isForward: true);
      final backwardGeo =
          geo(progress: 0.15, isDoubleSpread: false, isForward: false);
      expect(
        flipSideShadowClipRect(forwardGeo).left,
        equals(forwardGeo.foldX),
      );
      expect(
        flipSideShadowClipRect(backwardGeo).left,
        equals(backwardGeo.foldX),
      );
    });
  });

  group('PageFlipSpineRevealClipper', () {
    test('shouldReclip when progress changes', () {
      final a = PageFlipSpineRevealClipper(geo: geo(progress: 0.85));
      final b = PageFlipSpineRevealClipper(geo: geo(progress: 0.9));
      expect(a.shouldReclip(b), isTrue);
    });
  });
}
