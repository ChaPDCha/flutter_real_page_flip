import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

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
  });
}
