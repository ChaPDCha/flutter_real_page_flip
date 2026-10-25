import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// A right-to-left book is the same engine run in mirror image: the spine is on
/// the right, the next page comes from a swipe toward the right, and the page
/// content itself is never mirrored. The default stays left-to-right even in an
/// RTL locale, so no existing book changes.
void main() {
  const config = PageFlipConfig(
    enableSound: false,
    enableHaptics: false,
    enableKeyboardNavigation: true,
  );

  // Left half red, right half blue, so any mirroring of a page is visible.
  // The keys exist once per page, on the page that is current at rest.
  Widget Function(BuildContext, int) twoToneBuilder(int visibleIndex) =>
      (context, index) => Row(
            // Fixed: the host's own layout direction is not what is under test.
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: ColoredBox(
                  key: index == visibleIndex ? const Key('left-half') : null,
                  color: const Color(0xFFFF0000),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  key: index == visibleIndex ? const Key('right-half') : null,
                  color: const Color(0xFF0000FF),
                ),
              ),
            ],
          );

  Future<List<int>> pumpBook(
    WidgetTester tester, {
    PageFlipReadingDirection direction = PageFlipReadingDirection.rtl,
    TextDirection ambient = TextDirection.ltr,
    IndexedWidgetBuilder? itemBuilder,
    int initialIndex = 0,
    PageFlipSpreadMode spreadMode = PageFlipSpreadMode.single,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: ambient,
          child: Scaffold(
            body: PageFlipWidget(
              itemCount: 5,
              initialIndex: initialIndex,
              config: config,
              spreadMode: spreadMode,
              readingDirection: direction,
              itemBuilder: itemBuilder ?? twoToneBuilder(initialIndex),
              onPageChanged: changes.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return changes;
  }

  void expectHalvesUnmirrored(WidgetTester tester) {
    final left = tester.getRect(find.byKey(const Key('left-half')));
    final right = tester.getRect(find.byKey(const Key('right-half')));
    expect(left, const Rect.fromLTWH(0, 0, 200, 600));
    expect(right, const Rect.fromLTWH(200, 0, 200, 600));
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.fling(find.byType(PageFlipWidget), Offset(dx, 0), 1500);
    await tester.pumpAndSettle();
  }

  group('page content', () {
    testWidgets('is not mirrored in a right-to-left book', (tester) async {
      await pumpBook(tester);

      expectHalvesUnmirrored(tester);
    });

    testWidgets('is not mirrored in a left-to-right book', (tester) async {
      await pumpBook(tester, direction: PageFlipReadingDirection.ltr);

      expectHalvesUnmirrored(tester);
    });

    testWidgets('is not mirrored in a right-to-left double spread',
        (tester) async {
      await pumpBook(tester, spreadMode: PageFlipSpreadMode.doubleSpread);

      expectHalvesUnmirrored(tester);
    });

    testWidgets('stays unmirrored on the page a turn lands on', (tester) async {
      await pumpBook(tester, itemBuilder: twoToneBuilder(1));

      await swipe(tester, 300);

      expectHalvesUnmirrored(tester);
    });
  });

  group('swipe', () {
    testWidgets('toward the right turns forward in an RTL book',
        (tester) async {
      final changes = await pumpBook(tester);

      await swipe(tester, 300);

      expect(changes, [1]);
    });

    testWidgets('toward the left turns back in an RTL book', (tester) async {
      final changes = await pumpBook(tester, initialIndex: 2);

      await swipe(tester, -300);

      expect(changes, [1]);
    });

    testWidgets('toward the left on the first page does nothing in RTL',
        (tester) async {
      final changes = await pumpBook(tester);

      await swipe(tester, -300);

      expect(changes, isEmpty);
    });

    testWidgets('toward the left still turns forward in an LTR book',
        (tester) async {
      final changes =
          await pumpBook(tester, direction: PageFlipReadingDirection.ltr);

      await swipe(tester, -300);

      expect(changes, [1]);
    });

    testWidgets('turns forward in a mirrored double spread', (tester) async {
      final changes = await pumpBook(
        tester,
        spreadMode: PageFlipSpreadMode.doubleSpread,
      );

      await swipe(tester, 300);

      expect(changes, [1]);
    });
  });

  group('edge taps', () {
    testWidgets('the left edge turns forward and the right edge back in RTL',
        (tester) async {
      final changes = await pumpBook(tester, initialIndex: 2);

      await tester.tapAt(const Offset(10, 300));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(390, 300));
      await tester.pumpAndSettle();

      expect(changes, [3, 2]);
    });

    testWidgets('the right edge turns forward in an LTR book', (tester) async {
      final changes = await pumpBook(
        tester,
        direction: PageFlipReadingDirection.ltr,
      );

      await tester.tapAt(const Offset(390, 300));
      await tester.pumpAndSettle();

      expect(changes, [1]);
    });
  });

  group('keyboard', () {
    testWidgets('the left arrow turns forward and the right arrow back in RTL',
        (tester) async {
      final changes = await pumpBook(tester, initialIndex: 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes, [3, 2]);
    });

    testWidgets('page down and space still turn forward in RTL',
        (tester) async {
      final changes = await pumpBook(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      expect(changes, [1, 2]);
    });
  });

  group('accessibility', () {
    testWidgets('scroll actions swap sides in RTL', (tester) async {
      final handle = tester.ensureSemantics();
      final changes = await pumpBook(tester, initialIndex: 2);
      final node = tester.getSemantics(find.bySemanticsLabel('Page 3 of 5'));

      expect(
        node.getSemanticsData().hasAction(SemanticsAction.scrollRight),
        isTrue,
      );
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.scrollRight);
      await tester.pumpAndSettle();

      expect(changes, [3]);
      handle.dispose();
    });

    testWidgets('increase and decrease keep their meaning in RTL',
        (tester) async {
      final handle = tester.ensureSemantics();
      final changes = await pumpBook(tester, initialIndex: 2);
      final node = tester.getSemantics(find.bySemanticsLabel('Page 3 of 5'));

      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();

      expect(changes, [3]);
      handle.dispose();
    });
  });

  group('reading direction source', () {
    testWidgets('ltr is the default even under an RTL Directionality',
        (tester) async {
      final changes = await pumpBook(
        tester,
        direction: PageFlipReadingDirection.ltr,
        ambient: TextDirection.rtl,
      );

      await swipe(tester, -300);

      expect(changes, [1]);
    });

    testWidgets('auto follows an RTL Directionality', (tester) async {
      final changes = await pumpBook(
        tester,
        direction: PageFlipReadingDirection.auto,
        ambient: TextDirection.rtl,
      );

      await swipe(tester, 300);

      expect(changes, [1]);
    });

    testWidgets('auto reads left-to-right under an LTR Directionality',
        (tester) async {
      final changes = await pumpBook(
        tester,
        direction: PageFlipReadingDirection.auto,
      );

      await swipe(tester, -300);

      expect(changes, [1]);
    });
  });

  group('changing direction', () {
    Widget book(
      TextDirection ambient,
      PageFlipReadingDirection direction,
      List<int> changes,
    ) =>
        MaterialApp(
          home: Directionality(
            textDirection: ambient,
            child: Scaffold(
              body: PageFlipWidget(
                itemCount: 5,
                initialIndex: 2,
                config: config,
                readingDirection: direction,
                itemBuilder: twoToneBuilder(2),
                onPageChanged: changes.add,
              ),
            ),
          ),
        );

    testWidgets('keeps the page and re-mirrors the swipe', (tester) async {
      final changes = await pumpBook(tester, initialIndex: 2);

      await tester.pumpWidget(
        book(TextDirection.ltr, PageFlipReadingDirection.ltr, changes),
      );
      await tester.pumpAndSettle();

      expectHalvesUnmirrored(tester);
      await swipe(tester, -300);
      expect(changes, [3]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an auto book follows a live Directionality change',
        (tester) async {
      final changes = await pumpBook(
        tester,
        direction: PageFlipReadingDirection.auto,
        initialIndex: 2,
      );

      await tester.pumpWidget(
        book(TextDirection.rtl, PageFlipReadingDirection.auto, changes),
      );
      await tester.pumpAndSettle();

      expectHalvesUnmirrored(tester);
      await swipe(tester, 300);
      expect(changes, [3]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a turn in the air ends when the direction changes',
        (tester) async {
      final changes = await pumpBook(tester, initialIndex: 2);
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();

      await tester.pumpWidget(
        book(TextDirection.ltr, PageFlipReadingDirection.ltr, changes),
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(changes, isNot(contains(3)));
      expectHalvesUnmirrored(tester);
    });
  });
}
