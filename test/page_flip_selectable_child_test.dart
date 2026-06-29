import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

/// Mirrors [BookReaderScreen] tap wrapper (raw [Listener], not [GestureDetector]).
Widget _readerLikeFlipHost({
  required int itemCount,
  required ValueChanged<int> onPageChanged,
  required IndexedWidgetBuilder pageBuilder,
  PageFlipSpreadMode spreadMode = PageFlipSpreadMode.single,
}) =>
    MaterialApp(
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) => Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) {},
            onPointerUp: (_) {},
            child: PageFlipWidget(
              itemCount: itemCount,
              spreadMode: spreadMode,
              config: const PageFlipConfig(
                sensitivity: 0.6,
                edgeTapWidthRatio: 0,
              ),
              onPageChanged: onPageChanged,
              itemBuilder: pageBuilder,
            ),
          ),
        ),
      ),
    );

/// Simulates [PdfPageRenderer] letterboxing (16:9 content on portrait viewport).
Widget letterboxedPage(int index, {required double viewportWidth}) {
  final contentHeight = viewportWidth * 9 / 16;
  return LayoutBuilder(
    builder: (context, constraints) => ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: constraints.maxWidth,
          height: contentHeight,
          child: ColoredBox(
            color: Color(0xFF101010 + index),
            child: Center(child: Text('PDF page $index')),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'horizontal drag flips page when child uses SelectableText',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) => Center(
            child: SelectableText(
              'Page $index content that spans the readable area.',
              textAlign: TextAlign.center,
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

  testWidgets(
    'PageFlipGestureLayer is top stack child when edge taps disabled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlipWidget(
              itemCount: 2,
              config: const PageFlipConfig(edgeTapWidthRatio: 0),
              itemBuilder: (_, __) => const Center(child: Text('x')),
            ),
          ),
        ),
      );

      final layerElement = tester.element(find.byType(PageFlipGestureLayer));
      final hostStack = layerElement.findAncestorWidgetOfExactType<Stack>()!;
      expect(hostStack.children.last, isA<PageFlipGestureLayer>());
    },
  );

  testWidgets(
    'letterbox band horizontal swipe completes flip in double spread',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          spreadMode: PageFlipSpreadMode.doubleSpread,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) =>
              letterboxedPage(index, viewportWidth: 1024),
        ),
      );

      // Swipe in top letterbox (outside 16:9 content band).
      await tester.dragFrom(const Offset(900, 40), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(currentPage, 1);
    },
  );

  testWidgets(
    'horizontal drag flips with reader-like nested GestureDetector + SelectableText.rich',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) => LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onDoubleTapDown: (_) {},
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: SelectableText.rich(
                  TextSpan(text: 'Page $index — selectable rich body text.'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Page 0'), findsOneWidget);

      final center = tester.getCenter(find.byType(PageFlipWidget));
      await tester.dragFrom(center, const Offset(-220, 0));
      await tester.pumpAndSettle();

      expect(currentPage, 1);
      expect(find.textContaining('Page 1'), findsOneWidget);
    },
  );

  testWidgets(
    'predominantly vertical drag does not flip page over SelectableText',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) => Center(
            child: SelectableText('Page $index'),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(PageFlipWidget));
      await tester.dragFrom(center, const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(currentPage, 0);
      expect(find.textContaining('Page 0'), findsOneWidget);
    },
  );

  testWidgets(
    'long press on SelectableText does not trigger page flip',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) => Center(
            child: SelectableText('Page $index'),
          ),
        ),
      );

      // Long press in center of page
      final center = tester.getCenter(find.byType(PageFlipWidget));
      await tester.longPressAt(center);
      await tester.pumpAndSettle();

      // Page should not have changed
      expect(currentPage, 0);
      expect(find.textContaining('Page 0'), findsOneWidget);
    },
  );

  testWidgets(
    'horizontal drag after failed long press still flips',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var currentPage = 0;

      await tester.pumpWidget(
        _readerLikeFlipHost(
          itemCount: 3,
          onPageChanged: (index) => currentPage = index,
          pageBuilder: (context, index) => Center(
            child: SelectableText('Page $index'),
          ),
        ),
      );

      // Long press first (does nothing)
      final center = tester.getCenter(find.byType(PageFlipWidget));
      await tester.longPressAt(center);
      await tester.pumpAndSettle();

      // Then drag to flip
      await tester.dragFrom(center, const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Page should have changed
      expect(currentPage, 1);
      expect(find.textContaining('Page 1'), findsOneWidget);
    },
  );
}
