import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('PageFlipWidget gesture integration', () {
    const viewSize = Size(400, 600);

    /// Screen size is 800×600 by default. SizedBox is centered by Center widget,
    /// so its origin is at screen offset (200, 0). All gesture coordinates below
    /// account for this offset.
    Widget buildTestWidget({
      required IndexedWidgetBuilder itemBuilder,
      int itemCount = 3,
      int initialIndex = 0,
      void Function(int)? onPageChanged,
      void Function()? onFlipEnd,
      PageFlipController? controller,
      PageFlipConfig config = PageFlipConfig.defaultSettings,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: viewSize,
                child: PageFlipWidget(
                  controller: controller,
                  initialIndex: initialIndex,
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                  onPageChanged: onPageChanged,
                  onFlipEnd: onFlipEnd,
                  config: config,
                ),
              ),
            ),
          ),
        );

    Widget defaultPage(BuildContext context, int index) => Container(
          color: [Colors.blue, Colors.red, Colors.green][index],
        );

    testWidgets('forward drag flips to next page', (tester) async {
      var changedPage = -1;
      var flipEnded = false;

      await tester.pumpWidget(
        buildTestWidget(
          itemBuilder: defaultPage,
          onPageChanged: (page) => changedPage = page,
          onFlipEnd: () => flipEnded = true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SizedBox at screen x=200..600. Start at screen x=550 (local 350), move -320.
      // This keeps the pointer within the SizedBox bounds (pointer retention).
      await tester.dragFrom(
        const Offset(550, 300),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(flipEnded, isTrue);
      expect(changedPage, 1);
    });

    testWidgets('backward drag flips to previous page', (tester) async {
      var changedPage = -1;

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 1,
          itemBuilder: defaultPage,
          onPageChanged: (page) => changedPage = page,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Start at screen x=230 (local 30), move +320 → screen x=550 (local 350).
      // Both within the SizedBox bounds.
      await tester.dragFrom(
        const Offset(230, 300),
        const Offset(320, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(changedPage, 0);
    });

    testWidgets('drag during animation is ignored (gesture freeze)', (
      tester,
    ) async {
      var flipCount = 0;

      await tester.pumpWidget(
        buildTestWidget(
          itemCount: 5,
          itemBuilder: (context, index) => ColoredBox(
            color: Colors.primaries[index % Colors.primaries.length],
          ),
          onPageChanged: (_) => flipCount++,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // First successful drag
      await tester.dragFrom(
        const Offset(550, 300),
        const Offset(-320, 0),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Second drag while still settling — should be ignored
      await tester.dragFrom(
        const Offset(550, 300),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(flipCount, 1);
    });

    testWidgets('edge tap flips pages', (tester) async {
      var changedPage = -1;

      await tester.pumpWidget(
        buildTestWidget(
          itemBuilder: defaultPage,
          onPageChanged: (page) => changedPage = page,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Right edge: edgeTapWidthRatio=0.1 → 40px from right of SizedBox.
      // SizedBox right edge is at screen x=600. Tap at screen x=580.
      await tester.tapAt(const Offset(580, 300));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(changedPage, 1);

      // Left edge: 40px from left of SizedBox. SizedBox left edge at screen x=200.
      changedPage = -1;
      await tester.tapAt(const Offset(220, 300));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(changedPage, 0);
    });

    testWidgets('boundary prevents out-of-bounds flips', (tester) async {
      var changedPage = -1;

      // Page 0: backward should be ignored
      await tester.pumpWidget(
        buildTestWidget(
          itemBuilder: defaultPage,
          onPageChanged: (page) => changedPage = page,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.dragFrom(
        const Offset(230, 300),
        const Offset(320, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(changedPage, -1);

      // Last page: forward should be ignored
      changedPage = -1;
      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 2,
          itemBuilder: defaultPage,
          onPageChanged: (page) => changedPage = page,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.dragFrom(
        const Offset(550, 300),
        const Offset(-320, 0),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(changedPage, -1);
    });

    testWidgets('semantics report correct page number', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestWidget(
          initialIndex: 1,
          itemBuilder: defaultPage,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);

      handle.dispose();
    });
  });
}
