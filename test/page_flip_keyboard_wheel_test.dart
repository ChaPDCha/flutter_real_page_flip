import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Desktop and web readers expect the keyboard and the mouse wheel to turn
/// pages. Both are opt-in so an existing host keeps its own shortcuts and its
/// own scrolling inside page content.
void main() {
  const instant = PageFlipConfig(
    enableSound: false,
    enableHaptics: false,
  );

  Future<List<int>> pumpBook(
    WidgetTester tester, {
    required PageFlipConfig config,
    int initialIndex = 0,
    int itemCount = 5,
  }) async {
    final changes = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: itemCount,
            initialIndex: initialIndex,
            config: config,
            itemBuilder: (context, index) =>
                ColoredBox(color: Colors.primaries[index]),
            onPageChanged: changes.add,
          ),
        ),
      ),
    );
    await tester.pump();
    return changes;
  }

  group('keyboard', () {
    testWidgets('does nothing unless enabled', (tester) async {
      final changes = await pumpBook(tester, config: instant);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(changes, isEmpty);
    });

    group('when enabled', () {
      final config = instant.copyWith(enableKeyboardNavigation: true);

      testWidgets('arrow right, page down and space turn forward',
          (tester) async {
        final changes = await pumpBook(tester, config: config);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(changes, [1, 2, 3]);
      });

      testWidgets('arrow left, page up and shift+space turn back',
          (tester) async {
        final changes = await pumpBook(tester, config: config, initialIndex: 4);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        expect(changes, [3, 2, 1]);
      });

      testWidgets('home and end go to the first and last page', (tester) async {
        final changes = await pumpBook(tester, config: config, initialIndex: 2);

        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();

        expect(changes, [4, 0]);
      });

      testWidgets('the book edges are respected', (tester) async {
        final changes = await pumpBook(tester, config: config, itemCount: 2);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();

        expect(changes, [1]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ctrl, alt and meta combinations are left alone',
          (tester) async {
        final changes = await pumpBook(tester, config: config);

        for (final modifier in [
          LogicalKeyboardKey.controlLeft,
          LogicalKeyboardKey.altLeft,
          LogicalKeyboardKey.metaLeft,
        ]) {
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.sendKeyUpEvent(modifier);
        }
        await tester.pump();

        expect(changes, isEmpty);
      });

      testWidgets('other keys are ignored', (tester) async {
        final changes = await pumpBook(tester, config: config);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();

        expect(changes, isEmpty);
      });

      testWidgets('a key pressed during an animated turn cannot skip a page',
          (tester) async {
        final changes = await pumpBook(
          tester,
          config: config.copyWith(skipTapAnimation: false),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();

        expect(changes, [1]);
      });
    });
  });

  group('mouse wheel', () {
    Future<TestPointer> mouseOverBook(WidgetTester tester) async {
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byType(PageFlipWidget))),
      );
      return pointer;
    }

    Future<void> scroll(
      WidgetTester tester,
      TestPointer pointer,
      Offset delta, {
      int atMs = 0,
    }) async {
      await tester.sendEventToBinding(
        pointer.scroll(delta, timeStamp: Duration(milliseconds: atMs)),
      );
      await tester.pump();
    }

    testWidgets('does nothing unless enabled', (tester) async {
      final changes = await pumpBook(tester, config: instant);
      final pointer = await mouseOverBook(tester);

      await scroll(tester, pointer, const Offset(0, 100));

      expect(changes, isEmpty);
    });

    group('when enabled', () {
      final config = instant.copyWith(enableWheelNavigation: true);

      testWidgets('scrolling down turns forward, up turns back',
          (tester) async {
        final changes = await pumpBook(tester, config: config, initialIndex: 2);
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, 100));
        await scroll(tester, pointer, const Offset(0, -100), atMs: 1000);

        expect(changes, [3, 2]);
      });

      testWidgets('horizontal scrolling works too', (tester) async {
        final changes = await pumpBook(tester, config: config);
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(100, 0));

        expect(changes, [1]);
      });

      testWidgets('one burst of events turns one page', (tester) async {
        final changes = await pumpBook(tester, config: config);
        final pointer = await mouseOverBook(tester);

        // A trackpad fling keeps sending events for a while.
        for (var i = 0; i < 8; i++) {
          await scroll(tester, pointer, const Offset(0, 60), atMs: i * 40);
        }

        expect(changes, [1]);
      });

      testWidgets('a new burst after a pause turns again', (tester) async {
        final changes = await pumpBook(tester, config: config);
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, 100));
        await scroll(tester, pointer, const Offset(0, 100), atMs: 600);

        expect(changes, [1, 2]);
      });

      testWidgets('tiny movements add up before they turn a page',
          (tester) async {
        final changes = await pumpBook(tester, config: config);
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, 4));
        expect(changes, isEmpty);

        await scroll(tester, pointer, const Offset(0, 40), atMs: 30);
        expect(changes, [1]);
      });

      testWidgets('ctrl + wheel is left for zoom', (tester) async {
        final changes = await pumpBook(tester, config: config);
        final pointer = await mouseOverBook(tester);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await scroll(tester, pointer, const Offset(0, 100));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

        expect(changes, isEmpty);
      });

      testWidgets('works with swipe gestures switched off', (tester) async {
        final changes = await pumpBook(
          tester,
          config: config.copyWith(enableSwipe: false),
        );
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, 100));

        expect(changes, [1]);
      });

      testWidgets('a scrollable page keeps the wheel until it reaches its end',
          (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final changes = <int>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PageFlipWidget(
                itemCount: 3,
                config: config,
                itemBuilder: (context, index) => index == 0
                    ? ListView(
                        controller: controller,
                        children: const [SizedBox(height: 1500)],
                      )
                    : ColoredBox(color: Colors.primaries[index]),
                onPageChanged: changes.add,
              ),
            ),
          ),
        );
        await tester.pump();
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, 100));
        expect(controller.offset, greaterThan(0), reason: 'the page scrolled');
        expect(changes, isEmpty, reason: 'and the book did not turn');

        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pump();
        await scroll(tester, pointer, const Offset(0, 100), atMs: 1000);
        expect(changes, [1], reason: 'at the end of the page the book turns');
      });

      testWidgets('the book edges are respected', (tester) async {
        final changes = await pumpBook(tester, config: config, itemCount: 2);
        final pointer = await mouseOverBook(tester);

        await scroll(tester, pointer, const Offset(0, -100));
        await scroll(tester, pointer, const Offset(0, 100), atMs: 1000);
        await scroll(tester, pointer, const Offset(0, 100), atMs: 2000);

        expect(changes, [1]);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
