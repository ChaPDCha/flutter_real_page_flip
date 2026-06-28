import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Stand-in for example [PdfPageRenderer] spreads: two labeled halves per index.
Widget mockPdfSpreadPage(BuildContext context, int spreadIndex) => Row(
    key: ValueKey('spread_$spreadIndex'),
    children: [
      Expanded(
        child: ColoredBox(
          color: Colors.primaries[spreadIndex % Colors.primaries.length],
          child: Center(child: Text('PDF L$spreadIndex')),
        ),
      ),
      Expanded(
        child: ColoredBox(
          color: Colors.primaries[(spreadIndex + 1) % Colors.primaries.length],
          child: Center(child: Text('PDF R$spreadIndex')),
        ),
      ),
    ],
  );

void main() {
  group('PageFlip PDF-style double-spread integration', () {
    /// 16:9 reader viewport (e.g. landscape tablet / wide phone).
    const viewSize = Size(640, 360);

    /// Default tester surface is 800×600; [Center] offsets the SizedBox origin.
    const centerDx = (800 - 640) / 2;
    const centerDy = (600 - 360) / 2;

    Widget buildReader({
      int itemCount = 4,
      int initialIndex = 0,
      void Function(int)? onPageChanged,
      bool isRightSwipe = false,
    }) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: viewSize,
              child: PageFlipWidget(
                initialIndex: initialIndex,
                itemCount: itemCount,
                isDoubleSpread: true,
                itemBuilder: mockPdfSpreadPage,
                onPageChanged: onPageChanged,
                config: isRightSwipe
                    ? const PageFlipConfig(isRightSwipe: true)
                    : const PageFlipConfig(),
              ),
            ),
          ),
        ),
      );

    testWidgets('forward half-width drag advances spread index', (
      tester,
    ) async {
      var changedSpread = -1;

      await tester.pumpWidget(
        buildReader(onPageChanged: (index) => changedSpread = index),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);

      // Double-spread drag extent is viewport width / 2 (320px). Start near
      // right edge in local coords, drag left by full half-width.
      final start = Offset(centerDx + 600, centerDy + viewSize.height / 2);
      await tester.dragFrom(start, const Offset(-320, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 1);
      expect(find.byKey(const ValueKey('spread_1')), findsOneWidget);
    });

    testWidgets('backward half-width drag returns to previous spread', (
      tester,
    ) async {
      var changedSpread = -1;

      await tester.pumpWidget(
        buildReader(
          initialIndex: 1,
          onPageChanged: (index) => changedSpread = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('spread_1')), findsOneWidget);

      final start = Offset(centerDx + 40, centerDy + viewSize.height / 2);
      await tester.dragFrom(start, const Offset(320, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 0);
      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);
    });

    testWidgets('isRightSwipe: forward swipe goes to previous spread', (
      tester,
    ) async {
      var changedSpread = -1;

      await tester.pumpWidget(
        buildReader(
          initialIndex: 1,
          isRightSwipe: true,
          onPageChanged: (index) => changedSpread = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('spread_1')), findsOneWidget);

      // With isRightSwipe, dragging right is "forward" = previous
      final start = Offset(centerDx + 320, centerDy + viewSize.height / 2);
      await tester.dragFrom(start, const Offset(320, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 0);
      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);
    });

    testWidgets('isRightSwipe: backward swipe goes to next spread', (
      tester,
    ) async {
      var changedSpread = -1;

      await tester.pumpWidget(
        buildReader(
          isRightSwipe: true,
          onPageChanged: (index) => changedSpread = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);

      // With isRightSwipe, dragging left is "backward" = next
      final start = Offset(centerDx + 600, centerDy + viewSize.height / 2);
      await tester.dragFrom(start, const Offset(-320, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 1);
      expect(find.byKey(const ValueKey('spread_1')), findsOneWidget);
    });

    testWidgets('tall narrow aspect ratio flip completes', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var changedSpread = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: const Size(360, 640),
                child: PageFlipWidget(
                  itemCount: 4,
                  isDoubleSpread: true,
                  itemBuilder: mockPdfSpreadPage,
                  onPageChanged: (index) => changedSpread = index,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drag in tall viewport
      await tester.dragFrom(const Offset(320, 400), const Offset(-200, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 1);
    });

    testWidgets('forward half-width drag completes in tall narrow viewport', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var changedSpread = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: const Size(360, 640),
                child: PageFlipWidget(
                  itemCount: 4,
                  isDoubleSpread: true,
                  itemBuilder: mockPdfSpreadPage,
                  onPageChanged: (index) => changedSpread = index,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Drag from right edge leftward
      await tester.dragFrom(const Offset(340, 400), const Offset(-180, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedSpread, 1);
    });

    testWidgets('isRightSwipe: leftward swipe goes to next spread',
        (tester) async {
      var changedSpread = -1;

      await tester.pumpWidget(
        buildReader(
          isRightSwipe: true,
          onPageChanged: (index) => changedSpread = index,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);

      // isRightSwipe inverts: leftward drag = backward, stays on same spread.
      // Drag from center-right of spread, enough to trigger threshold.
      final start = Offset(centerDx + 500, centerDy + viewSize.height / 2);
      await tester.dragFrom(start, const Offset(-250, 0));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // With isRightSwipe, leftward drag is "backward" so it stays (no change).
      expect(changedSpread, -1);
      expect(find.byKey(const ValueKey('spread_0')), findsOneWidget);
    });
  });
}
