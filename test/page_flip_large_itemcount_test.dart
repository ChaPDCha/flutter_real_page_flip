import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

import 'utils/test_helpers.dart';

void main() {
  group('PageFlipWidget large itemCount', () {
    testWidgets('1000 pages renders initial page without crash',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 1000,
            itemBuilder: (context, index) =>
                Text('Page $index', key: ValueKey('page_$index')),
          ),
        ),
      );

      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('1000 pages programmatic goToPage works', (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 1000,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(500);
      await tester.pumpAndSettle();

      expect(currentIndex, equals(500));
    });

    testWidgets('1000 pages programmatic nextPage 3 times', (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 1000,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(currentIndex, 1);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(currentIndex, 2);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(currentIndex, 3);
    });

    testWidgets('1000 pages goToPage to last page then goToPage back',
        (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 1000,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(999);
      await tester.pumpAndSettle();
      expect(currentIndex, 999);

      await controller.goToPage(0);
      await tester.pumpAndSettle();
      expect(currentIndex, 0);
    });

    testWidgets('1000 pages goToPage out of bounds is no-op', (tester) async {
      final controller = PageFlipController();
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 1000,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(-1);
      await tester.pumpAndSettle();
      expect(currentIndex, 0);

      await controller.goToPage(1000);
      await tester.pumpAndSettle();
      expect(currentIndex, 0);
    });

    testWidgets('1000 pages sequential nextPage at end is no-op',
        (tester) async {
      final controller = PageFlipController();
      int currentIndex = 999;
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 999,
            itemCount: 1000,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) {
              currentIndex = index;
              callbackCount++;
            },
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(callbackCount, 0);
      expect(currentIndex, 999);
    });
  });
}
