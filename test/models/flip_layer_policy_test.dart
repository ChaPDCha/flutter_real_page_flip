import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/flip_layer_policy.dart';

void main() {
  group('FlipLayerPolicy — four-mode layer allocation', () {
    const itemCount = 5;

    // ─── bottomSpreadHalf (double mode only) ───

    group('bottomSpreadHalf', () {
      test('double forward returns next spread index, right-aligned', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        final result = policy.bottomSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 3);
        expect(result.alignment, Alignment.centerRight);
      });

      test('double forward at last spread returns null (paper fallback)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 4,
          itemCount: itemCount,
        );
        expect(policy.bottomSpreadHalf, isNull);
      });

      test('double backward returns previous index, left-aligned', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 3,
          itemCount: itemCount,
        );
        final result = policy.bottomSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 2);
        expect(result.alignment, Alignment.centerLeft);
      });

      test('double backward at index 0 returns null (paper fallback)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 0,
          itemCount: itemCount,
        );
        expect(policy.bottomSpreadHalf, isNull);
      });

      test('single mode returns null (uses bottomPageIndex instead)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.bottomSpreadHalf, isNull);
      });
    });

    // ─── middleSpreadHalf (double mode only) ───

    group('middleSpreadHalf', () {
      test('double forward returns current index, left-aligned', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        final result = policy.middleSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 2);
        expect(result.alignment, Alignment.centerLeft);
      });

      test('double forward at last spread still returns current index', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 4,
          itemCount: itemCount,
        );
        final result = policy.middleSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 4);
        expect(result.alignment, Alignment.centerLeft);
      });

      test('double backward returns current index, right-aligned', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 3,
          itemCount: itemCount,
        );
        final result = policy.middleSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 3);
        expect(result.alignment, Alignment.centerRight);
      });

      test('double backward at index 0 still returns current index', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 0,
          itemCount: itemCount,
        );
        final result = policy.middleSpreadHalf;
        expect(result, isNotNull);
        expect(result!.index, 0);
        expect(result.alignment, Alignment.centerRight);
      });

      test('single mode returns null (uses middlePageIndex instead)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middleSpreadHalf, isNull);
      });
    });

    // ─── bottomPageIndex (single mode only) ───

    group('bottomPageIndex', () {
      test('single forward returns next page', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 1,
          itemCount: itemCount,
        );
        expect(policy.bottomPageIndex, 2);
      });

      test('single forward at last page returns null', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 4,
          itemCount: itemCount,
        );
        expect(policy.bottomPageIndex, isNull);
      });

      test('single backward returns currentIndex (underside)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.bottomPageIndex, 2);
      });

      test('single backward at index 0 returns currentIndex (still valid)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 0,
          itemCount: itemCount,
        );
        expect(policy.bottomPageIndex, 0);
      });

      test('double mode returns null (uses bottomSpreadHalf)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.bottomPageIndex, isNull);
      });
    });

    // ─── middleSpreadIndex ───

    group('middleSpreadIndex', () {
      test('double forward returns currentIndex', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middleSpreadIndex, 2);
      });

      test('double backward returns currentIndex', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middleSpreadIndex, 2);
      });

      test('single mode returns null', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middleSpreadIndex, isNull);
      });
    });

    // ─── middlePageIndex ───

    group('middlePageIndex', () {
      test('single forward returns currentIndex (stationary content)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middlePageIndex, 2);
      });

      test('single backward returns previous page', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 3,
          itemCount: itemCount,
        );
        expect(policy.middlePageIndex, 2);
      });

      test('single backward at index 0 returns null', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 0,
          itemCount: itemCount,
        );
        expect(policy.middlePageIndex, isNull);
      });

      test('double mode returns null (uses middleSpreadIndex)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.middlePageIndex, isNull);
      });
    });

    // ─── flapSnapshotSpreadIndex ───

    group('flapSnapshotSpreadIndex', () {
      test('double mode returns currentIndex', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.flapSnapshotSpreadIndex, 2);
      });

      test('double backward returns currentIndex', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.flapSnapshotSpreadIndex, 2);
      });

      test('single forward returns currentIndex', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 1,
          itemCount: itemCount,
        );
        expect(policy.flapSnapshotSpreadIndex, 1);
      });

      test(
          'single backward returns previous page index (peels previous page from left)',
          () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.flapSnapshotSpreadIndex, 1);
      });
    });

    // ─── flapBackSnapshotSpreadIndex (2.5D back content) ───

    group('flapBackSnapshotSpreadIndex', () {
      test('double forward returns next spread index', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 2,
          itemCount: itemCount,
        );
        expect(policy.flapBackSnapshotSpreadIndex, 3);
      });

      test('double forward at last spread returns null', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 4,
          itemCount: itemCount,
        );
        expect(policy.flapBackSnapshotSpreadIndex, isNull);
      });

      test('double backward returns previous spread index', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 3,
          itemCount: itemCount,
        );
        expect(policy.flapBackSnapshotSpreadIndex, 2);
      });

      test('double backward at first spread returns null', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: false,
          currentIndex: 0,
          itemCount: itemCount,
        );
        expect(policy.flapBackSnapshotSpreadIndex, isNull);
      });

      test('single mode returns null regardless of direction', () {
        expect(
          FlipLayerPolicy(
            isDoubleSpread: false,
            isForward: true,
            currentIndex: 2,
            itemCount: itemCount,
          ).flapBackSnapshotSpreadIndex,
          isNull,
        );
        expect(
          FlipLayerPolicy(
            isDoubleSpread: false,
            isForward: false,
            currentIndex: 2,
            itemCount: itemCount,
          ).flapBackSnapshotSpreadIndex,
          isNull,
        );
      });
    });

    // ─── Edge: single-item collection ───

    group('single-item collection (itemCount=1)', () {
      test(
          'double forward at index 0: bottom returns null (no next spread), middle=current',
          () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: true,
          isForward: true,
          currentIndex: 0,
          itemCount: 1,
        );
        // No next spread to reveal
        expect(policy.bottomSpreadHalf, isNull);
        expect(policy.bottomPageIndex, isNull);
        expect(policy.middleSpreadHalf, isNotNull);
        expect(policy.middleSpreadHalf!.index, 0);
        expect(policy.middleSpreadHalf!.alignment, Alignment.centerLeft);
        expect(policy.middlePageIndex, isNull);
        expect(policy.flapSnapshotSpreadIndex, 0);
      });

      test(
          'single backward at index 0: bottomPageIndex=0, middlePageIndex=null',
          () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: false,
          currentIndex: 0,
          itemCount: 1,
        );
        expect(policy.bottomSpreadHalf, isNull);
        expect(policy.bottomPageIndex, 0);
        expect(policy.middleSpreadIndex, isNull);
        expect(policy.middlePageIndex, isNull);
        expect(policy.flapSnapshotSpreadIndex, isNull);
      });

      test(
          'single forward at index 0: bottomPageIndex=null (out of bounds), '
          'middlePageIndex=0 (current page stays)', () {
        final policy = FlipLayerPolicy(
          isDoubleSpread: false,
          isForward: true,
          currentIndex: 0,
          itemCount: 1,
        );
        expect(policy.bottomPageIndex, isNull);
        expect(policy.middlePageIndex, 0);
      });
    });
  });
}
