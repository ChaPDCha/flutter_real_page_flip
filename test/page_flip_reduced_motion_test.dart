import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// The platform's "reduce motion" setting (iOS Reduce Motion, Android "Remove
/// animations", the browser's prefers-reduced-motion) reaches Flutter as
/// `MediaQueryData.disableAnimations`. People who turn it on can get dizzy or
/// sick from large sweeping motion, so the engine follows it by default.
void main() {
  const quiet = PageFlipConfig(
    enableSound: false,
    enableHaptics: false,
    skipTapAnimation: false,
  );

  void setReduceMotion(WidgetTester tester, {required bool value}) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Pumps a four-page book and reports what the host sees.
  Future<_Book> pumpBook(
    WidgetTester tester, {
    PageFlipConfig config = quiet,
    _Book? existingBook,
  }) async {
    final book = existingBook ?? _Book();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            controller: book.controller,
            itemCount: 4,
            config: config,
            itemBuilder: (context, index) =>
                ColoredBox(color: Colors.primaries[index]),
            onPageChanged: book.changes.add,
            onFlipStart: () => book.lifecycle.add('start'),
            onFlipEnd: () => book.lifecycle.add('end'),
          ),
        ),
      ),
    );
    await tester.pump();
    return book;
  }

  Future<void> dragAndRelease(
    WidgetTester tester, {
    double dragFraction = 0.5,
  }) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final gesture = await tester.startGesture(
      Offset(size.width * 0.8, size.height / 2),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.moveBy(Offset(-size.width * dragFraction, 0));
    await tester.pump();
    await gesture.up();
    // A short animation needs a frame to start its clock and another to end:
    // two frames of real time, then one more for the post-frame hand-off.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
  }

  group('with the system setting off', () {
    testWidgets('a tap turn animates as before', (tester) async {
      setReduceMotion(tester, value: false);
      final book = await pumpBook(tester);

      book.controller.nextPage();
      await tester.pump(const Duration(milliseconds: 50));
      expect(book.changes, isEmpty, reason: 'the turn is still in the air');

      await tester.pumpAndSettle();
      expect(book.changes, [1]);
    });

    testWidgets('a released drag is still settling after a moment',
        (tester) async {
      setReduceMotion(tester, value: false);
      final book = await pumpBook(tester);

      await dragAndRelease(tester);
      expect(book.changes, isEmpty, reason: 'control: the settle takes longer');

      await tester.pumpAndSettle();
      expect(book.changes, [1]);
    });
  });

  group('with the system setting on', () {
    testWidgets('a tap turn changes page at once', (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(tester);

      book.controller.nextPage();
      await tester.pump();

      expect(book.changes, [1]);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the edge tap area also turns at once', (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(tester);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width * 0.95, size.height / 2));
      await tester.pump();

      expect(book.changes, [1]);
    });

    testWidgets('previous page is instant too', (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(tester);

      await book.controller.goToPage(2);
      await tester.pump();
      book.changes.clear();
      book.controller.previousPage();
      await tester.pump();

      expect(book.changes, [1]);
    });

    testWidgets('the host still sees one start and one end per turn',
        (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(tester);

      book.controller.nextPage();
      await tester.pump();

      expect(book.lifecycle, ['start', 'end']);
    });

    testWidgets(
        'explicit instant swipe policy snaps to its destination quickly',
        (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(
        tester,
        config: quiet.copyWith(preserveSwipeSettleOnReducedMotion: false),
      );

      await dragAndRelease(tester);

      expect(book.changes, [1]);
    });

    testWidgets('respectReducedMotion: false keeps the animation',
        (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(
        tester,
        config: quiet.copyWith(respectReducedMotion: false),
      );

      book.controller.nextPage();
      await tester.pump(const Duration(milliseconds: 50));
      expect(book.changes, isEmpty);

      await tester.pumpAndSettle();
      expect(book.changes, [1]);
    });

    for (final commits in [true, false]) {
      testWidgets(
        'default swipe policy preserves ${commits ? 'completion' : 'snap-back'} '
        'while tap turns stay instant',
        (tester) async {
          setReduceMotion(tester, value: true);
          final book = await pumpBook(tester);

          await dragAndRelease(tester, dragFraction: commits ? 0.5 : 0.1);
          expect(book.lifecycle, ['start']);
          expect(tester.hasRunningAnimations, isTrue);
          expect(book.changes, isEmpty);

          await tester.pumpAndSettle();
          expect(book.lifecycle, ['start', 'end']);
          expect(book.changes, commits ? [1] : <int>[]);

          book.controller.nextPage();
          await tester.pump();
          expect(book.changes.last, commits ? 2 : 1);
          expect(tester.hasRunningAnimations, isFalse);
        },
      );
    }

    testWidgets('changing the swipe option affects the next turn only',
        (tester) async {
      setReduceMotion(tester, value: true);
      final book = await pumpBook(
        tester,
        config: quiet.copyWith(preserveSwipeSettleOnReducedMotion: true),
      );

      await dragAndRelease(tester);
      expect(book.lifecycle, ['start']);
      await pumpBook(
        tester,
        existingBook: book,
        config: quiet.copyWith(preserveSwipeSettleOnReducedMotion: false),
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(book.lifecycle, ['start']);

      await tester.pumpAndSettle();
      expect(book.changes, [1]);
      expect(book.lifecycle, ['start', 'end']);

      // Reduced motion now shortens the new release to a single-frame settle.
      await dragAndRelease(tester);
      expect(book.changes, [1, 2]);
      expect(book.lifecycle, ['start', 'end', 'start', 'end']);
    });
  });

  testWidgets('follows the setting when it changes while the book is open',
      (tester) async {
    setReduceMotion(tester, value: false);
    final book = await pumpBook(tester);

    book.controller.nextPage();
    await tester.pumpAndSettle();
    expect(book.changes, [1]);

    setReduceMotion(tester, value: true);
    await tester.pump();
    book.controller.nextPage();
    await tester.pump();

    expect(book.changes, [1, 2]);
  });
}

/// What a host of the book can observe.
class _Book {
  final PageFlipController controller = PageFlipController();
  final List<int> changes = <int>[];
  final List<String> lifecycle = <String>[];
}
