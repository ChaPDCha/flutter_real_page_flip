import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

import 'utils/test_helpers.dart';

/// Turn ownership: exactly one actor (a finger, a tap flip, or a jump) drives
/// a turn, every `onFlipStart` gets exactly one `onFlipEnd`, and a turn the
/// book can no longer honour is aborted instead of finishing out of range.
void main() {
  group('PageFlipStateController ownership', () {
    late PageFlipStateController controller;
    late List<int> finalized;
    late int starts;
    late int ends;

    setUp(() {
      finalized = <int>[];
      starts = 0;
      ends = 0;
      controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 200),
        onUpdate: () {},
        onPageFinalized: finalized.add,
        onFlipStart: () => starts++,
        onFlipEnd: () => ends++,
        onEffectTrigger: (
          effect, {
          intensity,
          volume,
          texture,
          resistance,
        }) {},
      )
        ..updateCachedWidth(400)
        ..updateCachedHeight(600);
    });

    tearDown(() => controller.dispose());

    bool startDrag(double dx) => controller.onDragStart(
          DragStartDetails(localPosition: const Offset(300, 300)),
          5,
          accumulatedTotalDx: dx,
        );

    void dragBy(double dx) => controller.onDragUpdate(
          DragUpdateDetails(
            delta: Offset(dx, 0),
            primaryDelta: dx,
            globalPosition: Offset.zero,
            localPosition: const Offset(300, 300),
          ),
          5,
        );

    testWidgets('a finger resting at a boundary owns the page', (tester) async {
      controller.setIndex(4, 5); // last page
      expect(startDrag(-30), isTrue, reason: 'forward is blocked, not refused');
      expect(controller.isDragging, isFalse);
      expect(controller.isGestureActive, isTrue);
      expect(controller.isBusy, isTrue);

      // A tap flip must not start underneath the held finger: it used to,
      // firing a second onFlipStart whose onFlipEnd never came.
      controller.triggerTapFlip(isNext: false, totalPages: 5);
      expect(controller.isDragging, isFalse);
      expect(starts, 1);

      controller.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      await tester.pumpAndSettle();
      expect(controller.isBusy, isFalse);
      expect(starts, 1);
      expect(ends, 1);
      expect(finalized, isEmpty);

      // Once the finger is gone the tap flip is accepted.
      controller.triggerTapFlip(isNext: false, totalPages: 5);
      await tester.pumpAndSettle();
      expect(finalized, <int>[3]);
      expect(starts, ends);
    });

    testWidgets('cancelActiveFlip during a drag disowns the finger',
        (tester) async {
      controller.setIndex(1, 5);
      expect(startDrag(-30), isTrue);
      dragBy(-120);
      expect(controller.dragProgress, greaterThan(0.3));

      controller.cancelActiveFlip();
      expect(controller.isBusy, isFalse);
      expect(controller.dragProgress, 0);
      expect(ends, 1);

      // The rest of that finger's sequence belongs to no turn.
      dragBy(-200);
      expect(controller.dragProgress, 0);
      expect(controller.isDragging, isFalse);
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -3000,
          velocity: const Velocity(pixelsPerSecond: Offset(-3000, 0)),
        ),
        5,
      );
      await tester.pumpAndSettle();
      expect(ends, 1, reason: 'no second onFlipEnd for the aborted turn');
      expect(finalized, isEmpty);
      expect(controller.currentIndex, 1);

      // The next finger starts a fresh, working turn.
      expect(startDrag(-30), isTrue);
      dragBy(-300);
      controller.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      await tester.pumpAndSettle();
      expect(finalized, <int>[2]);
      expect(starts, ends);
    });

    testWidgets('cancelActiveFlip during a committed settle keeps the page',
        (tester) async {
      controller.setIndex(1, 5);
      startDrag(-30);
      dragBy(-250);
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -800,
          velocity: const Velocity(pixelsPerSecond: Offset(-800, 0)),
        ),
        5,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isSettling, isTrue);

      controller.cancelActiveFlip();
      await tester.pumpAndSettle();

      expect(finalized, isEmpty, reason: 'the aborted turn must not land');
      expect(controller.currentIndex, 1);
      expect(controller.isBusy, isFalse);
      expect(starts, 1);
      expect(ends, 1);
    });

    test('cancelActiveFlip while idle is a no-op', () {
      controller.cancelActiveFlip();
      expect(ends, 0);
      expect(controller.isBusy, isFalse);
    });
  });

  group('PageFlipWidget ownership', () {
    Widget book({
      required int count,
      int initialIndex = 0,
      bool skipTapAnimation = false,
      bool enableSwipe = true,
      PageFlipController? controller,
      List<int>? changes,
      List<String>? lifecycle,
    }) =>
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: PageFlipWidget(
                key: const ValueKey<String>('book'),
                controller: controller,
                itemCount: count,
                initialIndex: initialIndex,
                config: PageFlipConfig(
                  duration: const Duration(milliseconds: 200),
                  skipTapAnimation: skipTapAnimation,
                  enableSwipe: enableSwipe,
                  effectHandler: const NoOpEffectHandler(),
                ),
                onPageChanged: changes?.add,
                onFlipStart: () => lifecycle?.add('start'),
                onFlipEnd: () => lifecycle?.add('end'),
                itemBuilder: (context, index) {
                  if (index >= count) {
                    throw StateError('built page $index of $count');
                  }
                  return ColoredBox(
                    color: Colors.primaries[index % Colors.primaries.length],
                    child: Text('p$index'),
                  );
                },
              ),
            ),
          ),
        );

    PageFlipWidgetState stateOf(WidgetTester tester) =>
        tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));

    testWidgets('removing the destination mid-turn aborts the turn',
        (tester) async {
      final controller = PageFlipController();
      final changes = <int>[];
      final lifecycle = <String>[];
      await tester.pumpWidget(
        book(
          count: 5,
          initialIndex: 3,
          controller: controller,
          changes: changes,
          lifecycle: lifecycle,
        ),
      );
      await tester.pumpAndSettle();

      controller.nextPage(); // animated turn 3 -> 4
      await tester.pump(const Duration(milliseconds: 16));
      expect(stateOf(tester).controller.isDragging, isTrue);

      // The host drops the last page while it is in the air. Finishing the
      // turn would land on page 4 of a 4-page book.
      await tester.pumpWidget(
        book(
          count: 4,
          initialIndex: 3,
          controller: controller,
          changes: changes,
          lifecycle: lifecycle,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(stateOf(tester).controller.currentIndex, 3);
      expect(stateOf(tester).controller.isBusy, isFalse);
      expect(changes, isEmpty);
      expect(lifecycle, <String>['start', 'end']);
      expect(find.text('p3'), findsWidgets);
    });

    testWidgets('a mid-turn shrink that keeps both pages lets the turn land',
        (tester) async {
      final controller = PageFlipController();
      final changes = <int>[];
      await tester.pumpWidget(
        book(count: 8, controller: controller, changes: changes),
      );
      await tester.pumpAndSettle();

      controller.nextPage(); // 0 -> 1
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pumpWidget(
        book(count: 3, controller: controller, changes: changes),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(changes, <int>[1]);
      expect(stateOf(tester).controller.currentIndex, 1);
    });

    testWidgets('disabling swipe mid-drag releases the page', (tester) async {
      final controller = PageFlipController();
      final lifecycle = <String>[];
      await tester.pumpWidget(
        book(
          count: 5,
          initialIndex: 1,
          controller: controller,
          lifecycle: lifecycle,
        ),
      );
      await tester.pumpAndSettle();

      final finger = await tester.startGesture(const Offset(300, 300));
      await finger.moveBy(const Offset(-40, 0));
      await finger.moveBy(const Offset(-60, 0));
      await tester.pump();
      final state = stateOf(tester);
      expect(state.controller.isDragging, isTrue);
      expect(state.controller.blocksContentPointers, isTrue);

      // The gesture layer unmounts while the finger is still down. Its
      // release can never arrive; the turn used to stay frozen forever with
      // page content pointer-blocked and every navigation refused.
      await tester.pumpWidget(
        book(
          count: 5,
          initialIndex: 1,
          controller: controller,
          lifecycle: lifecycle,
          enableSwipe: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(state.controller.isBusy, isFalse);
      expect(state.controller.blocksContentPointers, isFalse);
      expect(state.controller.currentIndex, 1);
      expect(lifecycle, <String>['start', 'end']);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(state.controller.currentIndex, 2);

      await finger.up();
      await tester.pumpAndSettle();
      expect(lifecycle, <String>['start', 'end', 'start', 'end']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refused instant navigation reports no lifecycle',
        (tester) async {
      final controller = PageFlipController();
      final lifecycle = <String>[];
      final changes = <int>[];
      await tester.pumpWidget(
        book(
          count: 3,
          initialIndex: 2,
          skipTapAnimation: true,
          controller: controller,
          lifecycle: lifecycle,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      controller.nextPage(); // already on the last page
      await tester.pump();
      expect(lifecycle, isEmpty, reason: 'nothing turned, nothing to report');
      expect(changes, isEmpty);

      controller.previousPage();
      await tester.pump();
      expect(lifecycle, <String>['start', 'end']);
      expect(changes, <int>[1]);
    });

    testWidgets('navigation is refused while a finger owns the page',
        (tester) async {
      final controller = PageFlipController();
      final lifecycle = <String>[];
      final changes = <int>[];
      await tester.pumpWidget(
        book(
          count: 3,
          initialIndex: 2,
          skipTapAnimation: true,
          controller: controller,
          lifecycle: lifecycle,
          changes: changes,
        ),
      );
      await tester.pumpAndSettle();

      // Forward swipe on the last page: blocked, but the finger owns it.
      final finger = await tester.startGesture(const Offset(300, 300));
      await finger.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(stateOf(tester).controller.isGestureActive, isTrue);

      controller.previousPage();
      await controller.goToPage(0);
      await tester.pump();
      expect(changes, isEmpty);
      expect(lifecycle, <String>['start'], reason: 'only the finger started');

      await finger.up();
      await tester.pumpAndSettle();
      expect(lifecycle, <String>['start', 'end']);

      await controller.goToPage(0);
      await tester.pump();
      expect(changes, <int>[0]);
    });
  });

  group('PageFlipWidget semantics at book boundaries', () {
    Future<SemanticsData> pageSemantics(
      WidgetTester tester, {
      required int count,
      required int index,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: count,
            initialIndex: index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
            itemBuilder: (context, i) => ColoredBox(
              color: Colors.primaries[i % Colors.primaries.length],
            ),
          ),
        ),
      );
      await tester.pump();
      final label = 'Page ${index + 1} of $count';
      final node = tester.getSemantics(find.bySemanticsLabel(label));
      return node.getSemanticsData();
    }

    testWidgets('last page announces no next value', (tester) async {
      final handle = tester.ensureSemantics();
      final data = await pageSemantics(tester, count: 3, index: 2);
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.increasedValue, isEmpty);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      expect(data.decreasedValue, '2');
      handle.dispose();
    });

    testWidgets('first page announces no previous value', (tester) async {
      final handle = tester.ensureSemantics();
      final data = await pageSemantics(tester, count: 3, index: 0);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      expect(data.decreasedValue, isEmpty);
      expect(data.increasedValue, '2');
      handle.dispose();
    });

    testWidgets('single-page book announces neither', (tester) async {
      final handle = tester.ensureSemantics();
      final data = await pageSemantics(tester, count: 1, index: 0);
      expect(data.increasedValue, isEmpty);
      expect(data.decreasedValue, isEmpty);
      expect(data.value, '1');
      handle.dispose();
    });
  });
}
