import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  testWidgets(
    'horizontal drag flips page when child uses SelectableText',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlipWidget(
              itemCount: 3,
              initialIndex: 0,
              onPageChanged: (index) => currentPage = index,
              itemBuilder: (context, index) => Center(
                child: SelectableText(
                  'Page $index content that spans the readable area.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Page 0'), findsOneWidget);

      final center = tester.getCenter(find.byType(PageFlipWidget));
      await tester.dragFrom(center, const Offset(-200, 0));
      await tester.pumpAndSettle();

      expect(currentPage, 1);
      expect(find.textContaining('Page 1'), findsOneWidget);
    },
  );
}
