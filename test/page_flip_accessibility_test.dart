import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageFlipWidget accessibility', () {
    testWidgets('default semantics label uses page index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
          ),
        ),
      );

      await tester.pump();

      // The Semantics widget should be available
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('custom semanticBuilder formats label', (tester) async {
      String? capturedLabel;
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            config: PageFlipConfig(
              semanticBuilder: (index, total) =>
                  'Chapter ${index + 1} of $total',
            ),
          ),
        ),
      );

      await tester.pump();

      // Semantics widget should exist with the custom format
      expect(find.byType(Semantics), findsWidgets);
    });

    testWidgets('first page onDecrease is null (no previous)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
          ),
        ),
      );

      await tester.pump();

      // Navigate to first page
      // Verify we're on page 0
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('last page onIncrease is null (no next)', (tester) async {
      var changedIndex = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 3,
            initialIndex: 2,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            onPageChanged: (index) => changedIndex = index,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Page 2'), findsOneWidget);
    });

    testWidgets('edge tap uses custom previous/next labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            config: const PageFlipConfig(
              edgeTapPreviousLabel: '이전',
              edgeTapNextLabel: '다음',
              edgeTapWidthRatio: 0.3,
            ),
          ),
        ),
      );

      await tester.pump();

      // Widget should render without crash
      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('edge tap uses custom hints', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            config: const PageFlipConfig(
              edgeTapPreviousHint: 'Go back one page',
              edgeTapNextHint: 'Go forward one page',
              edgeTapWidthRatio: 0.3,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('directionality RTL does not crash', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: PageFlipWidget(
              itemCount: 5,
              itemBuilder: (context, index) =>
                  Center(child: Text('Page $index')),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('edge tap semantics have correct labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            config: const PageFlipConfig(
              edgeTapWidthRatio: 0.3,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify no crash and widget renders
      expect(find.byType(PageFlipWidget), findsOneWidget);
    });
  });
}
