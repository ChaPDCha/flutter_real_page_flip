import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  const variants = [
    (PageFlipReadingDirection.ltr, PageFlipSpreadMode.single, false),
    (PageFlipReadingDirection.rtl, PageFlipSpreadMode.single, true),
    (PageFlipReadingDirection.ltr, PageFlipSpreadMode.doubleSpread, true),
    (PageFlipReadingDirection.rtl, PageFlipSpreadMode.doubleSpread, false),
  ];

  for (final (direction, spread, reducedMotion) in variants) {
    testWidgets(
      '${direction.name}/${spread.name}, reducedMotion=$reducedMotion: '
      'rapid reversals cannot steal a turn and a fresh swipe works at rest',
      (tester) async {
        final book = _SwipeBook(tester, direction: direction, spread: spread);
        await book.mount(reducedMotion: reducedMotion);

        // Each 52px swipe is below the cutoff, even for a half-width spread.
        // It commits only if the timestamped release velocity has the right sign.
        const directions = [true, false, true, false, true, false, true, true];
        var index = 1;
        final expected = <String>[];
        for (final forward in directions) {
          final target = index + (forward ? 1 : -1);
          final finger = book.startSwipe(forward: forward, distance: 52);
          expected.add('start');
          expect(book.events, expected);
          expect(book.state.isForward, forward);
          expect(book.state.blocksContentPointers, isTrue);
          expect(book.state.dragProgress, lessThan(0.4));
          await tester.pump();

          final held = book.view;
          book.lift(finger);
          expect(book.state.isSettling, isTrue);
          expect(book.state.blocksContentPointers, isFalse);
          await tester.pump();
          expect(book.view.dragProgress, held.dragProgress);
          expect(book.view.touchPosition, held.touchPosition);

          // A second finger crosses the slop during the previous release.
          // Keep it down until after the turn lands, then move and lift it.
          final rejected = book.startSwipe(forward: !forward, distance: 52);
          book.navigation.previousPage();
          book.navigation.nextPage();
          expect(book.events, expected);
          expect(book.state.currentIndex, index);

          var previousProgress = held.dragProgress;
          for (final ms in [8, 16, 16, 32, 40, 16]) {
            await tester.pump(Duration(milliseconds: ms));
            if (book.state.isSettling) {
              final progress = book.state.dragProgress;
              expect(progress, inInclusiveRange(previousProgress, 1.0));
              expect(book.state.isForward, forward);
              expect(book.state.touchPosition, held.touchPosition);
              previousProgress = progress;
            }
          }
          expect(previousProgress, greaterThan(held.dragProgress));
          await tester.pump();
          expected.addAll(['page $target', 'end']);
          book.expectIdleAt(target);
          expect(book.events, expected);

          book.move(rejected, const Offset(70, 0));
          book.lift(rejected);
          expect(book.events, expected);
          book.expectIdleAt(target);
          // The next real swipe starts at this frame, without pumpAndSettle.
          index = target;
        }
      },
    );
  }

  for (final completes in [true, false]) {
    testWidgets(
      'a swipe released at ${completes ? 'full' : 'zero'} progress still '
      'owns the turn through the same pointer batch',
      (tester) async {
        final book = _SwipeBook(tester);
        await book.mount();

        // Move outside the viewport to overshoot 1.0. Reversing by the same
        // distance overshoots 0.0. Both endpoints leave no distance to animate.
        final first = book.startSwipe(forward: true, distance: 440);
        expect(book.state.dragProgress, 1);
        if (!completes) {
          book.move(first, const Offset(440, 0));
          expect(book.state.dragProgress, 0);
        }
        await tester.pump(const Duration(milliseconds: 80));

        // Dispatch all events synchronously, as one platform pointer packet
        // can do. The completion Future has not had a microtask to finalize.
        book.lift(first);
        final competing = book.startSwipe(forward: false, distance: 52);
        book.lift(competing);
        final eventsInPacket = List<String>.of(book.events);

        await tester.pumpAndSettle();
        expect(book.events, ['start', if (completes) 'page 2', 'end']);
        expect(eventsInPacket, ['start']);
        book.expectIdleAt(completes ? 2 : 1);
      },
    );
  }

  for (final systemCancels in [true, false]) {
    testWidgets(
      '${systemCancels ? 'pointer cancellation' : 'a reverse fling'} beyond '
      'the cutoff settles back once before the next swipe',
      (tester) async {
        final book = _SwipeBook(tester);
        await book.mount(reducedMotion: true);
        final finger = book.startSwipe(forward: true, distance: 270);
        if (!systemCancels) {
          // Leave a gap in the samples so the last three moves establish a
          // fast reverse release while the fold is still past the cutoff.
          book.move(
            finger,
            const Offset(14, 0),
            gap: const Duration(milliseconds: 60),
          );
          book.move(finger, const Offset(14, 0));
          book.move(finger, const Offset(14, 0));
        }
        await tester.pump();
        var previousProgress = book.view.dragProgress;
        expect(previousProgress, greaterThan(0.4));

        if (systemCancels) {
          book.cancel(finger);
        } else {
          book.lift(finger);
        }
        expect(book.state.isSettling, isTrue);
        expect(book.state.blocksContentPointers, isFalse);
        await tester.pump();

        final rejected = book.startSwipe(forward: true, distance: 52);
        book.lift(rejected);
        expect(book.events, ['start']);
        for (final ms in [16, 32, 48, 64, 48]) {
          await tester.pump(Duration(milliseconds: ms));
          final progress = book.state.dragProgress;
          expect(progress, inInclusiveRange(0, previousProgress));
          previousProgress = progress;
        }
        expect(book.events, ['start', 'end']);
        book.expectIdleAt(1);

        final fresh = book.startSwipe(forward: true, distance: 52);
        book.lift(fresh);
        await tester.pumpAndSettle();
        expect(book.events, ['start', 'end', 'start', 'page 2', 'end']);
        book.expectIdleAt(2);
      },
    );
  }
}

class _SwipeBook {
  _SwipeBook(
    this.tester, {
    this.direction = PageFlipReadingDirection.ltr,
    this.spread = PageFlipSpreadMode.single,
  });

  static const _size = Size(400, 400);
  final WidgetTester tester;
  final PageFlipReadingDirection direction;
  final PageFlipSpreadMode spread;
  final navigation = PageFlipController();
  final events = <String>[];
  var _nextPointer = 1;
  var _eventTime = Duration.zero;

  Future<void> mount({bool reducedMotion = false}) async {
    tester.view
      ..physicalSize = _size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reducedMotion);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            controller: navigation,
            itemCount: 4,
            initialIndex: 1,
            readingDirection: direction,
            spreadMode: spread,
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 200),
              edgeTapWidthRatio: 0,
              enableSound: false,
              enableHaptics: false,
            ),
            onFlipStart: () => events.add('start'),
            onFlipEnd: () => events.add('end'),
            onPageChanged: (index) => events.add('page $index'),
            itemBuilder: (context, index) =>
                ColoredBox(color: Colors.primaries[index]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  PageFlipWidgetState get _widgetState =>
      tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));

  PageFlipStateController get state => _widgetState.controller;

  PageFlipLayerView get view =>
      tester.widget<PageFlipLayerView>(find.byType(PageFlipLayerView));

  Duration _nextTime([Duration gap = const Duration(milliseconds: 5)]) =>
      _eventTime += gap;

  TestPointer startSwipe({required bool forward, required double distance}) {
    final movesLeft = forward != (direction == PageFlipReadingDirection.rtl);
    final dx = movesLeft ? -distance : distance;
    final pointer = TestPointer(_nextPointer++);
    final start = Offset(_size.width * (movesLeft ? 0.8 : 0.2), 130);
    tester.binding
        .handlePointerEvent(pointer.down(start, timeStamp: _nextTime()));
    move(pointer, Offset(dx / 2, 0));
    move(pointer, Offset(dx / 2, 0));
    return pointer;
  }

  void move(
    TestPointer pointer,
    Offset delta, {
    Duration gap = const Duration(milliseconds: 5),
  }) {
    tester.binding.handlePointerEvent(
      pointer.move(pointer.location! + delta, timeStamp: _nextTime(gap)),
    );
  }

  void lift(TestPointer pointer) => tester.binding.handlePointerEvent(
        pointer.up(timeStamp: _nextTime()),
      );

  void cancel(TestPointer pointer) => tester.binding.handlePointerEvent(
        pointer.cancel(timeStamp: _nextTime()),
      );

  void expectIdleAt(int index) {
    expect(tester.takeException(), isNull);
    expect(state.currentIndex, index);
    expect(state.isBusy, isFalse);
    expect(state.blocksContentPointers, isFalse);
    expect(state.dragProgress, 0);
    expect(view.currentIndex, index);
    expect(view.isDragging, isFalse);
  }
}
