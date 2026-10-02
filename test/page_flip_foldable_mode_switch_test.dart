import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

import 'utils/foldable_test_support.dart';

/// Unfolding a foldable usually also switches the host from one page per index
/// to a two-page spread. Every index then means a different page, so the
/// switch must neither report a stale index nor leave the book without
/// snapshots for longer than a few frames.
void main() {
  group('switching between one page and a spread', () {
    testWidgets(
        'unfolding into a two-page spread mid-drag lands on the host page',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      resizeViewTo(tester, cover10x16.size);
      var starts = 0;
      var ends = 0;
      await tester.pumpWidget(
        foldBook(
          itemCount: 16,
          initialIndex: 7,
          onFlipStart: () => starts++,
          onFlipEnd: () => ends++,
        ),
      );
      await tester.pumpAndSettle();
      final state = foldStateOf(tester);

      final gesture = await tester.startGesture(const Offset(400, 300));
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(state.controller.isDragging, isTrue);

      // The host unfolds: wider screen, two pages per spread. Page 7 is on
      // spread 3 (pages 6 and 7), and 16 pages become 8 spreads.
      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pumpWidget(
        foldBook(
          mode: PageFlipSpreadMode.doubleSpread,
          itemCount: 8,
          initialIndex: 3,
          onFlipStart: () => starts++,
          onFlipEnd: () => ends++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(state.controller.currentIndex, 3);
      expect(state.controller.isBusy, isFalse);
      expect(starts - ends, 0);
      expect(
        windowMatches(state, inner4x3Landscape.size),
        isTrue,
        reason: 'The spread snapshots belong to the new viewport',
      );
    });

    testWidgets(
        'unfolding while a page is settling cancels that turn instead of '
        'reporting an index of the old numbering', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      resizeViewTo(tester, cover10x16.size);
      final controller = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(home: ReadingHost(controller: controller)),
      );
      await tester.pumpAndSettle();
      final state = foldStateOf(tester);
      final host = tester.state<ReadingHostState>(find.byType(ReadingHost));
      await controller.goToPage(7);
      await tester.pumpAndSettle();
      expect(host.page, 7);

      // A quick forward flick, released well before the end: the turn settles
      // toward page 8 (single-page numbering) over the host's 400 ms.
      final width = cover10x16.size.width;
      final gesture = await tester.startGesture(Offset(width - 12, 300));
      await gesture.moveBy(Offset(-width * 0.15, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(Offset(-width * 0.15, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 40));
      expect(state.controller.isSettling, isTrue);

      // The host unfolds into a spread while the page is still in the air.
      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pump();
      await pumpFrames(tester, 6);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        host.reported,
        <int>[7],
        reason: 'The settling turn was counted in single pages; its index '
            'must not reach a host that now counts spreads',
      );
      expect(host.page, 7);
      expect(state.controller.currentIndex, 3);
      expect(state.controller.isBusy, isFalse);
      expect(host.flipStarts, host.flipEnds);
      expect(find.text('page 6'), findsWidgets);
      expect(find.text('page 7'), findsWidgets);
    });

    testWidgets(
        'a spread-mode switch cancels a turn in the air even when the item '
        'count does not change', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      resizeViewTo(tester, cover10x16.size);
      var starts = 0;
      var ends = 0;
      final changes = <int>[];
      Widget book({required PageFlipSpreadMode mode, required int initial}) =>
          foldBook(
            mode: mode,
            itemCount: 24,
            initialIndex: initial,
            duration: const Duration(milliseconds: 400),
            onPageChanged: changes.add,
            onFlipStart: () => starts++,
            onFlipEnd: () => ends++,
          );
      await tester.pumpWidget(
        book(mode: PageFlipSpreadMode.single, initial: 7),
      );
      await tester.pumpAndSettle();
      final state = foldStateOf(tester);

      // A quick forward flick, released early: the turn settles toward page 8.
      final width = cover10x16.size.width;
      final gesture = await tester.startGesture(Offset(width - 12, 300));
      await gesture.moveBy(Offset(-width * 0.15, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(Offset(-width * 0.15, 0));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 40));
      expect(state.controller.isSettling, isTrue);

      // The host switches to a spread and keeps 24 items in both modes, so
      // the turn's destination is still inside the book. Page 7 is spread 3.
      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pumpWidget(
        book(mode: PageFlipSpreadMode.doubleSpread, initial: 3),
      );
      await pumpFrames(tester, 6);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        changes,
        isEmpty,
        reason: 'The cancelled turn was counted in single pages; reporting it '
            'to a host that now counts spreads loses the place the reader was on',
      );
      expect(state.controller.currentIndex, 3);
      expect(state.controller.isBusy, isFalse);
      expect((starts, ends), (1, 1));
    });

    testWidgets(
        'a mode switch that arrives one frame after the size jump still gets '
        'a fresh window within a few frames', (tester) async {
      addTearDown(tester.view.reset);
      final state = await openFoldBook(tester, cover10x16.size);

      // Frame N: the window changes shape. Frame N+1: the host reacts to it
      // (a state-managed host, or a post-frame setState) and switches to a
      // spread, which resets the snapshot cache.
      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pump();
      await tester.pumpWidget(
        foldBook(
          mode: PageFlipSpreadMode.doubleSpread,
          itemCount: 6,
          initialIndex: 2,
        ),
      );
      await pumpFrames(tester, 6);

      expect(
        windowMatches(state, inner4x3Landscape.size),
        isTrue,
        reason: 'After a reset there is nothing to protect, so waiting out '
            'the debounce only leaves the book without snapshots',
      );
      expect(state.debugDirtySnapshotIndices, isEmpty);
    });

    testWidgets(
        'the host pattern from the README keeps the reader on the same page '
        'across unfold and fold', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      resizeViewTo(tester, cover10x16.size);
      final controller = PageFlipController();
      await tester.pumpWidget(
        MaterialApp(home: ReadingHost(controller: controller)),
      );
      await tester.pumpAndSettle();
      final state = foldStateOf(tester);

      // Read on the cover display (one page per index) up to page 7.
      await controller.goToPage(7);
      await tester.pumpAndSettle();
      expect(state.controller.currentIndex, 7);

      // Unfold: 4:3 is wide enough for a spread, and page 7 is on spread 3.
      resizeViewTo(tester, inner4x3Landscape.size);
      await tester.pump();
      await pumpFrames(tester, 6);
      await tester.pumpAndSettle();
      expect(state.controller.currentIndex, 3);
      expect(find.text('page 6'), findsWidgets);
      expect(find.text('page 7'), findsWidgets);

      // Turn one spread forward (pages 8 and 9), then fold again.
      controller.nextPage();
      await tester.pumpAndSettle();
      expect(state.controller.currentIndex, 4);

      resizeViewTo(tester, cover10x16.size);
      await tester.pump();
      await pumpFrames(tester, 6);
      await tester.pumpAndSettle();
      expect(state.controller.currentIndex, 8);
      expect(find.text('page 8'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
      'foldable session soak: folds, rotations, mode switches and turns keep '
      'the index in range, the lifecycle balanced and the window fresh',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    final random = math.Random(20261002);
    const shapes = <FoldShape>[
      cover10x16,
      inner4x3Landscape,
      inner3x4Portrait,
      cover21x9,
      inner10x9Portrait,
      outer3x4,
    ];

    var spread = false;
    var itemCount = 24;
    var initialIndex = 7;
    var starts = 0;
    var ends = 0;
    var shape = shapes[0];
    resizeViewTo(tester, shape.size);

    Widget build() => foldBook(
          mode: spread
              ? PageFlipSpreadMode.doubleSpread
              : PageFlipSpreadMode.single,
          itemCount: itemCount,
          initialIndex: initialIndex,
          onFlipStart: () => starts++,
          onFlipEnd: () => ends++,
        );

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    final state = foldStateOf(tester);

    void checkInvariants(String step) {
      expect(tester.takeException(), isNull, reason: step);
      final index = state.controller.currentIndex;
      expect(index, inInclusiveRange(0, itemCount - 1), reason: step);
      final open = starts - ends;
      expect(open, inInclusiveRange(0, 1), reason: step);
      if (!state.controller.isBusy) {
        expect(open, 0, reason: '$step: idle book with an open turn');
      }
    }

    Future<void> dragTurn(String step) async {
      final width = shape.size.width;
      final extent = spread ? width / 2 : width;
      final forward = random.nextBool();
      final startX = forward ? width - 10 : 10.0;
      final gesture = await tester.startGesture(
        Offset(startX, shape.size.height * (0.2 + random.nextDouble() * 0.6)),
      );
      final sign = forward ? -1.0 : 1.0;
      await gesture.moveBy(Offset(sign * extent * 0.2, 0));
      await tester.pump(const Duration(milliseconds: 16));
      if (random.nextInt(3) == 0) {
        // The screen changes shape while the finger is still down.
        shape = shapes[random.nextInt(shapes.length)];
        resizeViewTo(tester, shape.size);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture
          .moveBy(Offset(sign * extent * random.nextDouble() * 0.5, 0));
      await tester.pump(const Duration(milliseconds: 16));
      if (random.nextInt(5) == 0) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      checkInvariants('$step release');
    }

    for (var step = 0; step < 90; step++) {
      final label = 'step $step';
      switch (random.nextInt(6)) {
        case 0:
          shape = shapes[random.nextInt(shapes.length)];
          resizeViewTo(tester, shape.size);
          await tester.pump();
        case 1:
          await dragTurn(label);
        case 2:
          foldStateOf(tester).nextPage();
        case 3:
          foldStateOf(tester).previousPage();
        case 4:
          // The host switches between one page and a two-page spread and
          // carries the reading position across.
          final current = state.controller.currentIndex;
          final page = spread ? current * 2 : current;
          spread = !spread;
          itemCount = spread ? 12 : 24;
          initialIndex = (spread ? page ~/ 2 : page).clamp(0, itemCount - 1);
          await tester.pumpWidget(build());
        case 5:
          break;
      }
      await tester.pump(Duration(milliseconds: random.nextInt(120)));
      checkInvariants(label);
    }

    // Let every deferred change and capture land.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();

    checkInvariants('final');
    expect(state.controller.isBusy, isFalse);
    expect(starts, ends);
    final current = state.controller.currentIndex;
    for (final index in <int>[current - 1, current, current + 1]) {
      if (index < 0 || index >= itemCount) continue;
      final snapshot = snapshotAspect(state, index);
      expect(snapshot, isNotNull, reason: 'snapshot $index');
      expect(
        (snapshot! / shape.aspect - 1).abs(),
        lessThan(0.01),
        reason: 'snapshot $index must match the final shape ${shape.name}',
      );
    }
    expect(state.debugDirtySnapshotIndices, isEmpty);
  });
}
