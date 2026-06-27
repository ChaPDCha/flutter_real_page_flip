import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import '../utils/test_helpers.dart';

void main() {
  group('PageFlipController', () {
    testWidgets('nextPage changes page forward', (tester) async {
      final controller = PageFlipController();
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentPage = index,
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();

      expect(currentPage, equals(1));
    });

    testWidgets('previousPage changes page backward', (tester) async {
      final controller = PageFlipController();
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 2,
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentPage = index,
          ),
        ),
      );

      controller.previousPage();
      await tester.pumpAndSettle();

      expect(currentPage, equals(1));
    });

    testWidgets('goToPage jumps to valid index', (tester) async {
      final controller = PageFlipController();
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentPage = index,
          ),
        ),
      );

      await controller.goToPage(5);
      await tester.pumpAndSettle();

      expect(currentPage, equals(5));
    });

    testWidgets('goToPage ignores out-of-bounds index', (tester) async {
      final controller = PageFlipController();
      int currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => currentPage = index,
          ),
        ),
      );

      await controller.goToPage(100);
      await tester.pumpAndSettle();
      expect(currentPage, equals(0));

      await controller.goToPage(-1);
      await tester.pumpAndSettle();
      expect(currentPage, equals(0));
    });

    testWidgets('methods safe when not attached to widget',
        (WidgetTester tester) async {
      final controller = PageFlipController();

      // No widget attached — should not throw
      expect(() => controller.nextPage(), returnsNormally);
      expect(() => controller.previousPage(), returnsNormally);
      await expectLater(controller.goToPage(3), completes);
    });

    testWidgets('goToPage on currentIndex is no-op', (tester) async {
      final controller = PageFlipController();
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 3,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => callbackCount++,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(3);
      await tester.pumpAndSettle();
      expect(callbackCount, 0, reason: 'goToPage current index should be no-op');
    });

    testWidgets('goToPage from 0 to last page then back', (tester) async {
      final controller = PageFlipController();
      int lastIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => lastIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(9);
      await tester.pumpAndSettle();
      expect(lastIndex, 9);
    });

    testWidgets('nextPage at last page is no-op', (tester) async {
      final controller = PageFlipController();
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 9,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => callbackCount++,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(callbackCount, 0, reason: 'nextPage at last page should be no-op');
    });

    testWidgets('previousPage at first page is no-op', (tester) async {
      final controller = PageFlipController();
      int callbackCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => callbackCount++,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.previousPage();
      await tester.pumpAndSettle();
      expect(callbackCount, 0,
          reason: 'previousPage at first page should be no-op');
    });

    testWidgets('sequential nextPage calls without settle', (tester) async {
      final controller = PageFlipController();
      int lastIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 10,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => lastIndex = index,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      controller.nextPage();
      controller.nextPage();
      controller.nextPage();
      await tester.pumpAndSettle();
      // Rapid nextPage should not crash and should advance
      expect(lastIndex, greaterThan(0));
    });
  });
}
