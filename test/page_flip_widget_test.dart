import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

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

      // Pre-rendering might load neighbors, but we expect at least the initial page to be processed
      // Our implementation keeps the current page and potentially neighbors in the stack.
      // Since it's using a Stack, all active pages might be in the tree.
      // Ideally, check for presence.

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

      // Trigger next page programmatically
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

      // Verify label
      expect(find.bySemanticsLabel('Page 1 of 2'), findsOneWidget);

      // Verify actions: At page 0, should support increase (next)
      // Check for Semantics with label and action
      final semanticsNode =
          tester.getSemantics(find.bySemanticsLabel('Page 1 of 2'));
      final semanticsData = semanticsNode.getSemanticsData();

      expect(semanticsData.hasAction(SemanticsAction.increase), isTrue);
      // Decrease should be disabled at page 0
      expect(semanticsData.hasAction(SemanticsAction.decrease), isFalse);

      // Trigger increase
      // Programmatically trigger next page to ensure state update logic works
      tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget)).nextPage();

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Should be at page 2 now
      expect(find.bySemanticsLabel('Page 2 of 2'), findsOneWidget);

      handle.dispose();
    });
  });
}
