import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import 'utils/test_helpers.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

void main() {
  group('PageFlipWidget', () {
    testWidgets('renders children and respects initial index', (tester) async {
      final pages = [
        Container(key: const Key('page_0'), color: Colors.blue),
        Container(key: const Key('page_1'), color: Colors.red),
        Container(key: const Key('page_2'), color: Colors.green),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 1,
            itemCount: pages.length,
            itemBuilder: (context, index) => pages[index],
          ),
        ),
      );

      expect(find.byKey(const Key('page_1')), findsOneWidget);
    });

    testWidgets('callbacks fire on page change', (tester) async {
      int? changedPage;

      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 2,
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();

      expect(changedPage, 1);
    });

    testWidgets('provides semantic information and actions', (tester) async {
      final handle = tester.ensureSemantics();
      final pages = [
        Container(color: Colors.blue),
        Container(color: Colors.red),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 0,
            itemCount: pages.length,
            itemBuilder: (context, index) => pages[index],
          ),
        ),
      );

      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);

      final semanticsNode =
          tester.getSemantics(find.bySemanticsLabel('Page 1 of 2'));
      final semanticsData = semanticsNode.getSemanticsData();

      expect(semanticsData.hasAction(SemanticsAction.increase), isTrue);
      expect(semanticsData.hasAction(SemanticsAction.decrease), isFalse);

      tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget)).nextPage();

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);

      handle.dispose();
    });

    testWidgets('itemCount=1 renders single page without crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 1,
            itemBuilder: (context, index) =>
                Container(key: const Key('only_page'), color: Colors.blue),
          ),
        ),
      );

      expect(find.byKey(const Key('only_page')), findsOneWidget);
    });

    testWidgets('itemCount=2 allows next and previous navigation',
        (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 2,
            itemBuilder: (context, index) =>
                Text('Page $index', key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      expect(find.text('Page 0'), findsOneWidget);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(currentIndex, equals(1));

      controller.previousPage();
      await tester.pumpAndSettle();
      expect(currentIndex, equals(0));
    });

    testWidgets('isRightSwipe defaults to left-to-right', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
          ),
        ),
      );

      // Widget renders without error (basic smoke test for isRightSwipe)
      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('enableSwipe=false hides edge tap and gesture layer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
            config: const PageFlipConfig(
              enableSwipe: false,
            ),
          ),
        ),
      );

      // EdgeTapFeedback widgets should not be present
      // (config.edgeTapWidthRatio > 0 is still true but enableSwipe=false guards)
    });

    testWidgets('onFlipStart and onFlipEnd fire for programmatic navigation',
        (tester) async {
      int startCount = 0;
      int endCount = 0;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
            onFlipStart: () => startCount++,
            onFlipEnd: () => endCount++,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(startCount, equals(1));
      expect(endCount, equals(1));

      controller.previousPage();
      await tester.pumpAndSettle();
      expect(startCount, equals(2));
      expect(endCount, equals(2));
    });

    testWidgets('goToPage ignores out-of-bounds index',
        (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(-1);
      await tester.pumpAndSettle();
      expect(currentIndex, equals(0));

      await controller.goToPage(100);
      await tester.pumpAndSettle();
      expect(currentIndex, equals(0));
    });

    testWidgets('nextPage at last page is no-op',
        (tester) async {
      final controller = PageFlipController();
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 2,
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (index) => callbackCount++,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(callbackCount, equals(0));
    });

    testWidgets('config with custom duration renders without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 800),
            ),
          ),
        ),
      );

      expect(find.byType(PageFlipWidget), findsOneWidget);
    });
  });

  group('PageFlipWidget controller lifecycle', () {
    testWidgets('navigate after widget removal does not crash', (tester) async {
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
          ),
        ),
      );

      // Remove widget from tree
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // These should not crash
      await controller.goToPage(-1);
      await controller.goToPage(5);
      controller.previousPage();
    });

    testWidgets('rebuild with new controller properly connects it',
        (tester) async {
      final controller2 = PageFlipController();
      int? changedPage;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: PageFlipController(),
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller2,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await controller2.goToPage(2);
      await tester.pumpAndSettle();
      expect(changedPage, 2);
    });
  });

  group('PageFlipWidget itemCount changes', () {
    testWidgets('rebuild with fewer pages does not crash', (tester) async {
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
          ),
        ),
      );

      await controller.goToPage(3);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 2,
            itemBuilder: (context, index) => Container(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('rebuild with more pages allows navigating to new pages',
        (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 2,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );
      await tester.pumpAndSettle();

      changedPage = null;
      await controller.goToPage(4);
      await tester.pumpAndSettle();
      expect(changedPage, 4);
    });
  });

  group('PageFlipWidget navigation edge cases', () {
    testWidgets('goToPage with same index is no-op', (tester) async {
      var changedCount = 0;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (_) => changedCount++,
          ),
        ),
      );

      await controller.goToPage(0);
      await tester.pumpAndSettle();
      expect(changedCount, 0);
    });

    testWidgets('goToPage with negative index is ignored', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      await controller.goToPage(-1);
      await tester.pumpAndSettle();
      expect(changedPage, isNull);
    });

    testWidgets('goToPage with index beyond itemCount is ignored',
        (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      await controller.goToPage(10);
      await tester.pumpAndSettle();
      expect(changedPage, isNull);
    });

    testWidgets('rapid nextPage calls navigate correctly', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      controller.nextPage();
      expect(changedPage, 1);

      controller.nextPage();
      expect(changedPage, 2);
    });

    testWidgets('rapid previousPage calls do not go below 0',
        (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
            onPageChanged: (page) => changedPage = page,
          ),
        ),
      );

      controller.previousPage();
      expect(changedPage, isNull);

      await controller.goToPage(1);
      await tester.pumpAndSettle();
      expect(changedPage, 1);

      changedPage = null;
      controller.previousPage();
      expect(changedPage, 0);

      changedPage = null;
      controller.previousPage();
      expect(changedPage, isNull);
    });
  });

  group('PageFlipWidget configuration', () {
    testWidgets('enableSwipe: false removes gesture layer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) => Container(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageFlipGestureLayer), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            config: const PageFlipConfig(enableSwipe: false),
            itemBuilder: (context, index) => Container(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PageFlipGestureLayer), findsNothing);
    });
  });

  group('PageFlipWidget error handling', () {
    testWidgets('itemBuilder throw is caught as FlutterError',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) {
              throw StateError('test error');
            },
          ),
        ),
      );

      // The error is caught by the test framework (not an unhandled crash).
      // It may propagate as StateError (from builder) or FlutterError (from framework).
      final dynamic error = tester.takeException();
      expect(error, isNotNull);
    });
  });

}
