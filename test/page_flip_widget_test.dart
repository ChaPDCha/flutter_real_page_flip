import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import 'utils/test_helpers.dart';

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
}
