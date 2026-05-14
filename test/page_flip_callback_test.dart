import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  group('PageFlipWidget callbacks', () {
    testWidgets('onPageChanged fires exactly once per successful transition',
        (tester) async {
      int callCount = 0;
      int? lastIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) {
              callCount++;
              lastIndex = index;
            },
          ),
        ),
      );

      // Use controller to flip
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(lastIndex, equals(1));
    });

    testWidgets('onPageFlipped fires exactly once per successful transition',
        (tester) async {
      int callCount = 0;
      int? lastIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageFlipped: (index) {
              callCount++;
              lastIndex = index;
            },
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(lastIndex, equals(1));
    });

    testWidgets('both callbacks receive identical index values',
        (tester) async {
      int? changedIndex;
      int? flippedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => changedIndex = index,
            onPageFlipped: (index) => flippedIndex = index,
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(changedIndex, equals(flippedIndex));
      expect(changedIndex, equals(1));
    });

    testWidgets('neither callback fires on out-of-bounds goToPage',
        (tester) async {
      int changedCount = 0;
      int flippedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (_) => changedCount++,
            onPageFlipped: (_) => flippedCount++,
            onFlipStart: () {},
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );

      // goToPage with negative index
      await state.goToPage(-1);
      await tester.pumpAndSettle();
      expect(changedCount, equals(0));
      expect(flippedCount, equals(0));

      // goToPage with index >= itemCount
      await state.goToPage(100);
      await tester.pumpAndSettle();
      expect(changedCount, equals(0));
      expect(flippedCount, equals(0));
    });
  });
}
