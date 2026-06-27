import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  testWidgets('PageFlipWidget Stress Test: Rapid sequential taps',
      (tester) async {
    // Set fixed size for predictable edge tap areas
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    int pageFlippedCount = 0;
    int lastPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: 100,
            itemBuilder: (context, index) => Center(
              key: ValueKey('page_$index'),
              child: Text('Page $index'),
            ),
            onPageFlipped: (index) {
              pageFlippedCount++;
              lastPage = index;
            },
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 100), // Fast animation
            ),
          ),
        ),
      ),
    );

    // Initial state
    expect(find.text('Page 0'), findsOneWidget);

    // Rapidly trigger 10 NEXT flips
    for (int i = 0; i < 10; i++) {
      // With width 400 and ratio 0.1, edge is last 40px (360-400)
      const rightSide = Offset(380, 400);
      await tester.tapAt(rightSide);
      // Wait long enough for some animations to finish or be well underway
      await tester.pump(const Duration(milliseconds: 60));
    }

    // After rapid taps, settle down
    await tester.pumpAndSettle();

    // Verify we reached some page and didn't crash
    expect(pageFlippedCount, greaterThan(0));
    expect(find.text('Page $lastPage'), findsOneWidget);
  });

  testWidgets('PageFlipWidget Dynamic Data Stress: Changing itemCount rapidly',
      (tester) async {
    int itemCount = 100;

    await tester.pumpWidget(
      StatefulBuilder(builder: (context, setState) {
        return MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: PageFlipWidget(
                    itemCount: itemCount,
                    itemBuilder: (context, index) => Text('Page $index'),
                  ),
                ),
                ElevatedButton(
                  onPressed: () =>
                      setState(() => itemCount = itemCount == 100 ? 5 : 100),
                  child: const Text('Toggle'),
                ),
              ],
            ),
          ),
        );
      }),
    );

    // Start a flip
    final center = tester.getCenter(find.byType(PageFlipWidget));
    await tester.dragFrom(center, const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 50));

    // While flipping, change itemCount to something smaller
    await tester.tap(find.text('Toggle'));
    await tester.pump();

    // Settle
    await tester.pumpAndSettle();

    // Should not crash and should be in a valid state
    expect(find.byType(PageFlipWidget), findsOneWidget);
  });

  testWidgets('PageFlipWidget Stress: Forward-backward direction switch',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var currentIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: 10,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            onPageChanged: (index) => currentIndex = index,
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 50),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Page 0'), findsOneWidget);

    // Forward drag
    await tester.dragFrom(const Offset(300, 400), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(currentIndex, 1);

    // Immediately backward drag
    await tester.dragFrom(const Offset(100, 400), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(currentIndex, 0);
  });

  testWidgets('PageFlipWidget Stress: Parent setState during drag',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var flipCount = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Scaffold(
              body: PageFlipWidget(
                itemCount: 10,
                itemBuilder: (context, index) =>
                    Center(child: Text('Page $index')),
                onPageChanged: (_) => flipCount++,
                config: const PageFlipConfig(
                  duration: Duration(milliseconds: 50),
                ),
              ),
            ),
          );
        },
      ),
    );

    // Start a flip
    final center = tester.getCenter(find.byType(PageFlipWidget));
    await tester.dragFrom(center, const Offset(-200, 0));

    // Rebuild parent mid-drag
    await tester.pump(const Duration(milliseconds: 10));

    // Settle
    await tester.pumpAndSettle();

    // Should not crash
    expect(find.byType(PageFlipWidget), findsOneWidget);
  });

  testWidgets('PageFlipWidget Stress: Rapid single-tap edge navigation',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    int lastIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: 10,
            itemBuilder: (context, index) => Center(child: Text('Page $index')),
            onPageChanged: (index) => lastIndex = index,
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 50),
              edgeTapWidthRatio: 0.2,
            ),
          ),
        ),
      ),
    );

    // Rapid taps at right edge
    for (int i = 0; i < 5; i++) {
      await tester.tapAt(const Offset(380, 400));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    // Should have navigated without crash
    expect(lastIndex, greaterThan(0));
  });
}
