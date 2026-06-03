import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Stand-in for example [PdfPageRenderer] spreads: two labeled halves per index.
Widget mockPdfSpreadPage(BuildContext context, int spreadIndex) {
  return Row(
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
}

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
    }) {
      return MaterialApp(
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
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('forward half-width drag advances spread index', (
      tester,
    ) async {
      int changedSpread = -1;

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
      int changedSpread = -1;

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
  });
}
