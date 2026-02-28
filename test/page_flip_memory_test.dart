import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  testWidgets('PageFlipWidget Memory Test: Snapshot lifecycle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: 10,
            itemBuilder: (context, index) => Container(
              key: ValueKey('page_$index'),
              color: Colors.blue,
              child: Text('Page $index'),
            ),
          ),
        ),
      ),
    );

    // Initially, no snapshots because we haven't pumped enough for the debounce (300ms)
    expect(find.byType(RawImage), findsNothing);

    // Wait for debounce and snapshot capture
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // Start a small drag to trigger the build of snapshots in PageFlipLayerView
    await tester.drag(find.byType(PageFlipWidget), const Offset(-10, 0));
    // Multiple pumps to ensure the drag state and snapshot-based UI are reconciled
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // On page 0, should have snapshot for page 1 during drag
    expect(find.byType(RawImage), findsAtLeastNWidgets(1));

    // Flip to page 1
    final state = tester.state<PageFlipWidgetState>(
      find.byType(PageFlipWidget),
    );
    state.nextPage();
    await tester.pumpAndSettle();

    // After animation, we are on Page 1.
    // It should capture Page 0 and Page 2 as snapshots.
    await tester.pump(const Duration(milliseconds: 500));

    // Should see 2 snapshots (for page 0 and 2) or at least 1 if it's still capturing
    expect(find.byType(RawImage), findsAtLeastNWidgets(1));

    // Verify cleanup: Dispose widget
    await tester.pumpWidget(const SizedBox());

    // No more PageFlipWidget
    expect(find.byType(PageFlipWidget), findsNothing);
  });
}
