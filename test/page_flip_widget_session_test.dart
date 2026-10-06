import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

import 'utils/test_helpers.dart';

/// Randomised end-to-end sessions against the real [PageFlipWidget].
///
/// Real pointer gestures (with timestamps, so flings carry velocity), edge
/// taps, controller navigation, host rebuilds that change the book under the
/// reader (item count, initial index, spread mode, tap animation, swipe
/// on/off), and resizes (foldable and rotation jumps, small window-drag steps)
/// are interleaved at random. After every step:
///
/// - the framework reported no error (duplicate keys, layout, build throws);
/// - `itemBuilder` was never asked for an index outside the book (it throws);
/// - the engine's page index is inside the book;
/// - `onPageChanged` only reports pages inside the book, and a turn moves
///   exactly one page (only `goToPage` may jump further);
/// - host lifecycle balance: `onFlipStart - onFlipEnd == (isBusy ? 1 : 0)`;
/// - with no finger down, page content is never left pointer-blocked.
///
/// Each session ends by lifting the finger and settling: the book must come
/// to rest idle, balanced, and showing its current page, every snapshot it
/// keeps must have the book's final shape, and once the book is gone every
/// snapshot image the session created must have been disposed.
void main() {
  const seeds = 14;
  const stepsPerSeed = 110;

  for (var seed = 0; seed < seeds; seed++) {
    testWidgets('widget session #$seed survives random use', (tester) async {
      final created = Set<ui.Image>.identity();
      final disposed = Set<ui.Image>.identity();
      void track(ObjectEvent event) {
        final object = event.object;
        if (object is! ui.Image) return;
        if (event is ObjectCreated) created.add(object);
        if (event is ObjectDisposed) disposed.add(object);
      }

      final allocations = FlutterMemoryAllocations.instance..addListener(track);
      addTearDown(() => allocations.removeListener(track));

      final session = _Session(tester, math.Random(1000 + seed));
      await session.start();

      for (var step = 0; step < stepsPerSeed; step++) {
        await session.randomStep();
        session.check('seed $seed, step $step');
      }

      await session.finish();
      session.check('seed $seed, final');
      final state = session.state;
      expect(state.controller.isBusy, isFalse, reason: session.trace);
      expect(session.starts, session.ends, reason: session.trace);
      if (session.count > 0) {
        expect(
          find.text('p${state.controller.currentIndex}'),
          findsWidgets,
          reason: session.trace,
        );
        // Every snapshot the next turn can draw has the book's final shape.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        session.checkSnapshotsFitTheBook('seed $seed, final');
      }

      // Dispose the book so no capture timer outlives the test, then let any
      // readback still in flight land and be disposed.
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(created, isNotEmpty, reason: 'leak tracking saw no images');
      final leaked = created.difference(disposed);
      expect(
        leaked,
        isEmpty,
        reason: '${leaked.length} snapshot image(s) leaked\n${session.trace}',
      );
    });
  }
}

class _Session {
  _Session(this.tester, this.random);

  final WidgetTester tester;
  final math.Random random;
  final PageFlipController controller = PageFlipController();

  int count = 6;
  int initialIndex = 0;
  Size bookSize = const Size(400, 600);
  bool skipTapAnimation = false;
  bool enableSwipe = true;
  bool doubleSpread = false;

  TestGesture? gesture;
  Duration gestureClock = Duration.zero;
  int nextPointer = 1;

  int starts = 0;
  int ends = 0;
  bool inGoToPage = false;
  int indexAtStepStart = 0;

  final List<String> _log = <String>[];
  String get trace => _log.skip(math.max(0, _log.length - 25)).join('\n');

  PageFlipWidgetState get state =>
      tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));

  void _record(String event) => _log.add(
        '$event -> idx=${state.controller.currentIndex}/$count '
        'busy=${state.controller.isBusy} '
        'finger=${gesture != null}',
      );

  Widget _page(BuildContext context, int index) {
    if (index < 0 || index >= count) {
      throw StateError('itemBuilder asked for page $index of $count');
    }
    return ColoredBox(
      color: Color(0xFF000000 | ((index * 0x2F2F2F) & 0xFFFFFF)),
      child: Text('p$index'),
    );
  }

  void _onPageChanged(int index) {
    expect(
      index,
      inInclusiveRange(0, math.max(0, count - 1)),
      reason: 'onPageChanged outside the book\n$trace',
    );
    if (!inGoToPage) {
      expect(
        (index - indexAtStepStart).abs(),
        1,
        reason: 'a turn must move exactly one page\n$trace',
      );
    }
  }

  Widget _app() => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: bookSize.width,
            height: bookSize.height,
            child: PageFlipWidget(
              key: const ValueKey<String>('book'),
              controller: controller,
              itemCount: count,
              initialIndex: initialIndex,
              spreadMode: doubleSpread
                  ? PageFlipSpreadMode.doubleSpread
                  : PageFlipSpreadMode.single,
              config: PageFlipConfig(
                duration: const Duration(milliseconds: 200),
                skipTapAnimation: skipTapAnimation,
                enableSwipe: enableSwipe,
                effectHandler: const NoOpEffectHandler(),
              ),
              onFlipStart: () => starts++,
              onFlipEnd: () => ends++,
              onPageChanged: _onPageChanged,
              itemBuilder: _page,
            ),
          ),
        ),
      );

  Future<void> start() async {
    await tester.pumpWidget(_app());
    await tester.pump();
    _record('start');
  }

  Future<void> randomStep() async {
    indexAtStepStart = state.controller.currentIndex;
    final roll = random.nextDouble();
    if (roll < 0.30) {
      await _gestureStep();
    } else if (roll < 0.40) {
      _navigate();
    } else if (roll < 0.45) {
      await _goToPage();
    } else if (roll < 0.56) {
      await _rebuild();
    } else if (roll < 0.63) {
      await _resize();
    } else {
      final ms = const <int>[0, 16, 16, 50, 120, 300][random.nextInt(6)];
      await tester.pump(Duration(milliseconds: ms));
      _record('pump ${ms}ms');
    }
  }

  Future<void> _gestureStep() async {
    final active = gesture;
    if (active == null) {
      final start = Offset(
        5 + random.nextDouble() * (bookSize.width - 10),
        5 + random.nextDouble() * (bookSize.height - 10),
      );
      gesture = await tester.startGesture(start, pointer: nextPointer++);
      gestureClock = Duration.zero;
      _record('down at ${start.dx.round()},${start.dy.round()}');
      return;
    }
    final roll = random.nextDouble();
    gestureClock += Duration(milliseconds: 8 + random.nextInt(24));
    if (roll < 0.70) {
      final dx = (random.nextDouble() * 2 - 1) * 90;
      final vertical = random.nextDouble() < 0.2;
      final dy = vertical ? (random.nextDouble() * 2 - 1) * 60 : 0.0;
      await active.moveBy(Offset(dx, dy), timeStamp: gestureClock);
      _record('move ${dx.round()},${dy.round()}');
    } else if (roll < 0.93) {
      await active.up(timeStamp: gestureClock);
      gesture = null;
      _record('up');
    } else {
      await active.cancel();
      gesture = null;
      _record('cancel');
    }
  }

  void _navigate() {
    if (random.nextBool()) {
      controller.nextPage();
      _record('controller.nextPage');
    } else {
      controller.previousPage();
      _record('controller.previousPage');
    }
  }

  Future<void> _goToPage() async {
    final target = random.nextInt(count + 2) - 1;
    inGoToPage = true;
    try {
      await controller.goToPage(target);
    } finally {
      inGoToPage = false;
    }
    _record('goToPage $target');
  }

  Future<void> _rebuild() async {
    final roll = random.nextDouble();
    final changes = <String>[];
    if (roll < 0.55) {
      count = random.nextDouble() < 0.08 ? 0 : 1 + random.nextInt(8);
      changes.add('count=$count');
    }
    if (random.nextDouble() < 0.3 && count > 0) {
      initialIndex = random.nextInt(count);
      changes.add('initialIndex=$initialIndex');
    }
    if (random.nextDouble() < 0.2) {
      skipTapAnimation = !skipTapAnimation;
      changes.add('skipTap=$skipTapAnimation');
    }
    if (random.nextDouble() < 0.12) {
      enableSwipe = !enableSwipe;
      changes.add('swipe=$enableSwipe');
    }
    if (random.nextDouble() < 0.08) {
      doubleSpread = !doubleSpread;
      changes.add('spread=$doubleSpread');
    }
    // PageFlipWidget asserts initialIndex < itemCount for a non-empty book.
    initialIndex = count == 0 ? 0 : math.min(initialIndex, count - 1);
    await tester.pumpWidget(_app());
    _record('rebuild ${changes.join(' ')}');
  }

  /// Shapes the book jumps between (foldable cover and inner displays, a
  /// rotation, a wide spread), all inside the 800x600 test window.
  static const List<Size> _shapes = <Size>[
    Size(400, 600),
    Size(600, 450),
    Size(380, 600),
    Size(560, 560),
    Size(250, 584),
    Size(780, 590),
    Size(300, 400),
  ];

  Future<void> _resize() async {
    if (random.nextDouble() < 0.6) {
      bookSize = _shapes[random.nextInt(_shapes.length)];
    } else {
      // A small step, like one frame of a window drag.
      final step = 1 + (random.nextDouble() * 2 - 1) * 0.04;
      bookSize = random.nextBool()
          ? Size((bookSize.width * step).clamp(120, 790), bookSize.height)
          : Size(bookSize.width, (bookSize.height * step).clamp(160, 595));
    }
    await tester.pumpWidget(_app());
    _record('resize ${bookSize.width.round()}x${bookSize.height.round()}');
  }

  /// Every snapshot kept for the window around the current page has the
  /// book's shape (a stretched snapshot is what a turn would draw).
  void checkSnapshotsFitTheBook(String where) {
    final c = state.controller;
    final aspect = bookSize.width / bookSize.height;
    for (var index = c.currentIndex - 1; index <= c.currentIndex + 1; index++) {
      if (index < 0 || index >= count) continue;
      final pixels = state.debugSnapshotPixelSize(index);
      if (pixels == null) continue;
      expect(
        ((pixels.width / pixels.height) / aspect - 1).abs(),
        lessThan(0.02),
        reason: '$where: snapshot $index is ${pixels.width}x${pixels.height} '
            'for a ${bookSize.width.round()}x${bookSize.height.round()} book\n'
            '$trace',
      );
    }
    expect(state.debugDirtySnapshotIndices, isEmpty, reason: '$where\n$trace');
  }

  Future<void> finish() async {
    final active = gesture;
    if (active != null) {
      gestureClock += const Duration(milliseconds: 16);
      await active.up(timeStamp: gestureClock);
      gesture = null;
    }
    await tester.pumpAndSettle();
    _record('finish');
  }

  void check(String where) {
    final reason = '$where\n$trace';
    expect(tester.takeException(), isNull, reason: reason);

    final c = state.controller;
    if (count == 0) {
      expect(c.currentIndex, 0, reason: reason);
    } else {
      expect(c.currentIndex, inInclusiveRange(0, count - 1), reason: reason);
    }
    expect(starts - ends, c.isBusy ? 1 : 0, reason: reason);
    expect(c.dragProgress.isFinite, isTrue, reason: reason);
    if (gesture == null) {
      expect(c.blocksContentPointers, isFalse, reason: reason);
    }
  }
}
