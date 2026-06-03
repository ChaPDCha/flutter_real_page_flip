import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  const canvasSize = Size(400, 300);

  Widget pumpLayerView({
    required double dragProgress,
    required bool isForward,
    int currentIndex = 0,
    int itemCount = 3,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox.fromSize(
          size: canvasSize,
          child: PageFlipLayerView(
            itemCount: itemCount,
            currentIndex: currentIndex,
            dragProgress: dragProgress,
            isDragging: true,
            isForward: isForward,
            touchPosition: const Offset(350, 150),
            pageSnapshots: const {},
            spreadSnapshots: const {},
            pageKeys: {
              for (var i = 0; i < itemCount; i++) i: GlobalKey(),
            },
            constrainedSize: canvasSize,
            isDoubleSpread: true,
            itemBuilder: (context, index) => ColoredBox(
              color: Colors.primaries[index % Colors.primaries.length],
              child: Center(child: Text('Page $index')),
            ),
          ),
        ),
      ),
    );
  }

  group('PageFlipLayerView double-spread spine reveal', () {
    testWidgets('includes PageFlipSpineRevealClipper during forward drag', (
      tester,
    ) async {
      await tester.pumpWidget(pumpLayerView(dragProgress: 0.9, isForward: true));

      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipClipper,
        ),
        findsOneWidget,
      );
    });

    testWidgets('includes PageFlipSpineRevealClipper during backward drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpLayerView(
          dragProgress: 0.9,
          isForward: false,
          currentIndex: 2,
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not stack Opacity on spine reveal', (tester) async {
      await tester.pumpWidget(pumpLayerView(dragProgress: 0.9, isForward: true));

      final clipper = tester.widget<ClipPath>(
        find.byWidgetPredicate(
          (w) =>
              w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
      );
      expect(clipper.child, isNot(isA<Opacity>()));
    });

    testWidgets('pre-render uses Offstage not Opacity', (tester) async {
      await tester.pumpWidget(
        pumpLayerView(dragProgress: 0.9, isForward: true, currentIndex: 1),
      );

      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Opacity && w.opacity == 0.0,
        ),
        findsNothing,
      );
    });

    testWidgets('forward drag spine reveal uses next spread not current', (
      tester,
    ) async {
      Future<ui.Image> spreadImage(Color left, Color right) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final halfW = canvasSize.width / 2;
        canvas.drawRect(
          Rect.fromLTWH(0, 0, halfW, canvasSize.height),
          Paint()..color = left,
        );
        canvas.drawRect(
          Rect.fromLTWH(halfW, 0, halfW, canvasSize.height),
          Paint()..color = right,
        );
        return recorder.endRecording().toImage(
              canvasSize.width.toInt(),
              canvasSize.height.toInt(),
            );
      }

      final currentSpread = await spreadImage(
        const Color(0xFFE53935),
        const Color(0xFF1E88E5),
      );
      final nextSpread = await spreadImage(
        const Color(0xFF43A047),
        const Color(0xFFFFB300),
      );
      addTearDown(currentSpread.dispose);
      addTearDown(nextSpread.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: 0.9,
                isDragging: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                pageSnapshots: const {},
                spreadSnapshots: {1: currentSpread, 2: nextSpread},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      final spineReveal = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
      );
      expect(spineReveal, findsOneWidget);

      final rawImage = tester.widget<RawImage>(
        find.descendant(of: spineReveal, matching: find.byType(RawImage)),
      );
      expect(rawImage.image, equals(nextSpread));
      expect(rawImage.image, isNot(equals(currentSpread)));
    });

    testWidgets('forward drag spine reveal uses next spread on left', (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 800, 300),
        Paint()..color = const Color(0xFF1E88E5),
      );
      final nextSpreadImage = await recorder.endRecording().toImage(800, 300);
      addTearDown(nextSpreadImage.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 0,
                dragProgress: 0.9,
                isDragging: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                pageSnapshots: const {},
                spreadSnapshots: {1: nextSpreadImage},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      final spineReveal = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
      );
      expect(spineReveal, findsOneWidget);
      expect(
        find.descendant(of: spineReveal, matching: find.byType(RawImage)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: spineReveal, matching: find.text('Spread 1')),
        findsNothing,
      );
    });

    testWidgets('omits spine reveal clipper when not dragging', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 0,
                dragProgress: 0.9,
                isDragging: false,
                isForward: true,
                touchPosition: Offset.zero,
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: {0: GlobalKey()},
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => const SizedBox(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
        findsNothing,
      );
    });
  });

  group('PageFlipLayerView single-page mode', () {
    Widget pumpSinglePageLayerView({
      required double dragProgress,
      required bool isForward,
      int currentIndex = 0,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox.fromSize(
            size: canvasSize,
            child: PageFlipLayerView(
              itemCount: 3,
              currentIndex: currentIndex,
              dragProgress: dragProgress,
              isDragging: true,
              isForward: isForward,
              touchPosition: const Offset(350, 150),
              pageSnapshots: const {},
              spreadSnapshots: const {},
              pageKeys: {
                for (var i = 0; i < 3; i++) i: GlobalKey(),
              },
              constrainedSize: canvasSize,
              isDoubleSpread: false,
              itemBuilder: (context, index) => ColoredBox(
                color: Colors.primaries[index % Colors.primaries.length],
                child: Center(child: Text('Page $index')),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('forward drag omits Offstage for next page in bottom layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpSinglePageLayerView(
          dragProgress: 0.85,
          isForward: true,
          currentIndex: 1,
        ),
      );

      // Page 2 is in the bottom layer; page 0 + keyed page 1 are Offstage.
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsNWidgets(2),
      );
      expect(find.text('Page 2'), findsWidgets);
    });

    testWidgets('forward drag middle layer does not host page GlobalKey', (
      tester,
    ) async {
      final currentKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: 0.85,
                isDragging: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: {
                  0: GlobalKey(),
                  1: currentKey,
                  2: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                itemBuilder: (context, index) => ColoredBox(
                  color: Colors.primaries[index % Colors.primaries.length],
                  child: Center(child: Text('Page $index')),
                ),
              ),
            ),
          ),
        ),
      );

      final middleClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      expect(middleClipper, findsOneWidget);
      expect(
        find.descendant(
          of: middleClipper,
          matching: find.byKey(currentKey),
        ),
        findsNothing,
      );
    });

    testWidgets('backward drag middle layer does not host page GlobalKey', (
      tester,
    ) async {
      final previousKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: 0.85,
                isDragging: true,
                isForward: false,
                touchPosition: const Offset(350, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: {
                  0: previousKey,
                  1: GlobalKey(),
                  2: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                itemBuilder: (context, index) => ColoredBox(
                  color: Colors.primaries[index % Colors.primaries.length],
                  child: Center(child: Text('Page $index')),
                ),
              ),
            ),
          ),
        ),
      );

      final middleClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      expect(middleClipper, findsOneWidget);
      expect(
        find.descendant(
          of: middleClipper,
          matching: find.byKey(previousKey),
        ),
        findsNothing,
      );
    });

    testWidgets('forward drag middle layer uses opaque paper underlay', (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 300),
        Paint()..color = const Color(0xFFE53935),
      );
      final image = await recorder.endRecording().toImage(400, 300);

      addTearDown(image.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: 0.85,
                isDragging: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                pageSnapshots: {1: image},
                spreadSnapshots: {1: image},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                paperFlapColor: const Color(0xFFF5F5F5),
                paperOpacity: 1.0,
                itemBuilder: (context, index) => Text('Page $index'),
              ),
            ),
          ),
        ),
      );

      final middleClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      expect(
        find.descendant(of: middleClipper, matching: find.byType(RawImage)),
        findsNothing,
      );
      expect(
        find.descendant(of: middleClipper, matching: find.text('Page 1')),
        findsNothing,
      );
      expect(
        find.descendant(of: middleClipper, matching: find.byType(ColoredBox)),
        findsOneWidget,
      );
    });

    testWidgets('backward drag omits Offstage for previous page in middle layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpSinglePageLayerView(
          dragProgress: 0.85,
          isForward: false,
          currentIndex: 1,
        ),
      );

      // Page 0 is in the middle layer; only page 2 is Offstage pre-render.
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsOneWidget,
      );
      expect(find.text('Page 0'), findsWidgets);
    });
  });
}
