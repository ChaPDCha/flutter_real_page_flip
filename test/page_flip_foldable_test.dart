import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

import 'utils/foldable_test_support.dart';

/// A foldable changes the book's shape in one step (cover display to inner
/// display, portrait to landscape). The snapshots the next turn draws were
/// captured at the old shape, so they must be replaced at once, never stretched
/// into the new viewport, and never flushed under a painter.
///
/// Switching between single page and spread at that moment is covered by
/// `page_flip_foldable_mode_switch_test.dart`.
void main() {
  for (final mode in PageFlipSpreadMode.values) {
    group('fold and unfold in $mode', () {
      for (final (from, to) in foldTransitions) {
        testWidgets(
            '${from.name} -> ${to.name}: snapshots follow the new shape '
            'within a few frames', (tester) async {
          addTearDown(tester.view.reset);
          final state = await openFoldBook(tester, from.size, mode: mode);
          expect(windowMatches(state, from.size), isTrue);

          resizeViewTo(tester, to.size);
          await tester.pump();
          // Six frames is ~100 ms: far below the 300 ms debounce that is
          // meant for continuous resizes, and short enough that no reader
          // has started a swipe on the freshly opened screen.
          await pumpFrames(tester, 6);

          expect(
            windowMatches(state, to.size),
            isTrue,
            reason: 'A shape jump leaves snapshots of the old proportions '
                'that every flip would stretch into the new viewport',
          );
          expect(state.debugDirtySnapshotIndices, isEmpty);
        });

        testWidgets(
            '${from.name} -> ${to.name}: a turn that starts after the jump '
            'draws no stretched page', (tester) async {
          addTearDown(tester.view.reset);
          final state = await openFoldBook(tester, from.size, mode: mode);

          resizeViewTo(tester, to.size);
          await tester.pump();
          await pumpFrames(tester, 6);

          final width = to.size.width;
          final extent =
              mode == PageFlipSpreadMode.doubleSpread ? width / 2 : width;
          final gesture = await tester.startGesture(
            Offset(width - 12, to.size.height * 0.5),
          );
          await gesture.moveBy(Offset(-extent * 0.15, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveBy(Offset(-extent * 0.15, 0));
          await tester.pump(const Duration(milliseconds: 16));

          expect(state.controller.isDragging, isTrue);
          expect(
            worstDrawnDistortion(tester),
            lessThan(1.02),
            reason: 'The page revealed behind the fold must keep its '
                'proportions',
          );

          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            '${from.name} -> ${to.name}: a turn that starts before the '
            'recapture lands draws no stretched page', (tester) async {
          addTearDown(tester.view.reset);
          final state = await openFoldBook(tester, from.size, mode: mode);

          // Only the layout frame of the new shape has run: the recapture is
          // queued for the next frame, and a turn started now blocks it.
          resizeViewTo(tester, to.size);
          await tester.pump();

          final width = to.size.width;
          final extent =
              mode == PageFlipSpreadMode.doubleSpread ? width / 2 : width;
          final gesture = await tester.startGesture(
            Offset(width - 12, to.size.height * 0.5),
          );
          await gesture.moveBy(Offset(-extent * 0.15, 0));
          await tester.pump(const Duration(milliseconds: 16));
          await gesture.moveBy(Offset(-extent * 0.15, 0));
          await tester.pump(const Duration(milliseconds: 16));

          expect(state.controller.isDragging, isTrue);
          expect(
            worstDrawnDistortion(tester),
            lessThan(1.02),
            reason: 'A turn that starts before the background recapture lands '
                'must not draw the old proportions for its whole length',
          );

          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  group('continuous resizing keeps its debounce', () {
    testWidgets('a window drag does not capture on every frame',
        (tester) async {
      addTearDown(tester.view.reset);
      final state = await openFoldBook(tester, const Size(816, 616));
      int captures() =>
          state.debugAsyncSnapshotCaptureCount +
          state.debugSyncSnapshotCaptureCount;
      final before = captures();

      // 40 frames, 3 px wider each: every step changes the shape by < 0.5%.
      for (var step = 1; step <= 40; step++) {
        resizeViewTo(tester, Size(816.0 + 3 * step, 616));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        captures(),
        before,
        reason: 'Capturing per frame while the user drags a window edge '
            'would flood the GPU with readbacks',
      );

      // Once the drag stops the window is recaptured exactly once.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(windowMatches(state, const Size(936, 616)), isTrue);
      expect(state.debugDirtySnapshotIndices, isEmpty);
      expect(captures() - before, lessThanOrEqualTo(4));
    });
  });

  group('replacing snapshots after a change of shape', () {
    testWidgets('keeps an image for every page of the window at every frame',
        (tester) async {
      addTearDown(tester.view.reset);
      final state = await openFoldBook(tester, cover10x16.size);

      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pump();
      for (var frame = 0; frame < 24; frame++) {
        for (final index in <int>[
          foldStartIndex - 1,
          foldStartIndex,
          foldStartIndex + 1,
        ]) {
          expect(
            state.debugSnapshotPixelSize(index),
            isNotNull,
            reason: 'Replacing must never leave blank paper: '
                'frame $frame, page $index',
          );
        }
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(windowMatches(state, inner4x3Landscape.size), isTrue);
    });

    testWidgets('a turn in the air keeps the snapshots it paints', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final state = await openFoldBook(tester, inner4x3Landscape.size);
      final before = state.debugSnapshotPixelSize(foldStartIndex + 1);
      expect(before, isNotNull);

      final gesture = await tester.startGesture(const Offset(800, 300));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.controller.isDragging, isTrue);

      resizeViewTo(tester, cover10x16.size);
      await pumpFrames(tester, 12);

      // The finger is still down: replacing the image the painter is using
      // would hand it a disposed handle, so the swap waits for the turn.
      expect(state.debugSnapshotPixelSize(foldStartIndex + 1), before);
      expect(tester.takeException(), isNull);

      await gesture.up();
      await tester.pumpAndSettle();
      await pumpFrames(tester, 6);
      expect(windowMatches(state, cover10x16.size), isTrue);
    });
  });

  testWidgets('a fold during a drag ends the turn cleanly', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    resizeViewTo(tester, inner4x3Landscape.size);
    var starts = 0;
    var ends = 0;
    final changes = <int>[];
    await tester.pumpWidget(
      foldBook(
        onPageChanged: changes.add,
        onFlipStart: () => starts++,
        onFlipEnd: () => ends++,
      ),
    );
    await tester.pumpAndSettle();
    final state = foldStateOf(tester);

    final gesture = await tester.startGesture(const Offset(800, 300));
    await gesture.moveBy(const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 16));
    resizeViewTo(tester, cover10x16.size);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(starts - ends, 0, reason: 'onFlipEnd balances onFlipStart');
    expect(state.controller.isBusy, isFalse);
    expect(
      state.controller.currentIndex,
      inInclusiveRange(0, foldItemCount - 1),
    );
    expect(windowMatches(state, cover10x16.size), isTrue);
  });
}
