import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  group('PageFlipWidget Lazy Loading', () {
    testWidgets('builder only calls itemBuilder for current and adjacent pages',
        (tester) async {
      final builtIndices = <int>{};
      const totalPages = 1000;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 500,
            itemCount: totalPages,
            itemBuilder: (context, index) {
              builtIndices.add(index);
              return Center(child: Text('Page $index'));
            },
          ),
        ),
      );

      // Initial build: current (500), prev (499), next (501)
      expect(builtIndices, contains(500));
      expect(builtIndices, contains(499));
      expect(builtIndices, contains(501));

      // Should NOT contain far indices
      expect(builtIndices.contains(0), isFalse);
      expect(builtIndices.contains(999), isFalse);

      // Total built pages should be low (3, or maybe a few more if pre-render snapshotting involves more)
      // Our windowing logic in PageFlipLayerView explicitly limits to {currentIndex, -1, +1}
      expect(builtIndices.length, lessThanOrEqualTo(5));
    });

    testWidgets('stress test: rapid flipping through many pages',
        (tester) async {
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 100,
            itemBuilder: (context, index) => SizedBox(
                key: ValueKey('page_$index'),
                child: Text('Page $index'),
              ),
          ),
        ),
      );

      // Flip rapidly
      for (var i = 0; i < 20; i++) {
        controller.nextPage();
        await tester.pump(); // Start animation
      }

      await tester.pumpAndSettle();

      // Should be at page 20
      expect(find.text('Page 20'), findsOneWidget);

      // Even after 20 flips, the number of active builders in the tree should be small
      // Note: buildCount tracks how many times itemBuilder was called, which might be more due to rebuilds,
      // but the tree should only contain a few Offstage pages.
      final offstageCount = tester.widgetList(find.byType(Offstage)).length;
      expect(offstageCount,
          lessThanOrEqualTo(4),); // prev, next + maybe old ones being disposed
    });
  });
}
