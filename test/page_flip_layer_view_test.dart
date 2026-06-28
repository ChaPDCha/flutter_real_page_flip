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

    testWidgets('forward drag shows opaque paper fallback when snapshot missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpSinglePageLayerView(
          dragProgress: 0.85,
          isForward: true,
          currentIndex: 1,
        ),
      );

      // When snapshots aren't ready, use opaque paper fallback instead of live page.
      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
      );
      expect(
        find.descendant(of: bottomClipper, matching: find.text('Page 2')),
        findsNothing,
      );
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

    testWidgets('forward drag middle layer shows current page content', (
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
      // Single forward: middle layer shows the current page snapshot
      expect(
        find.descendant(of: middleClipper, matching: find.byType(RawImage)),
        findsOneWidget,
      );
    });

    testWidgets('backward double-spread middle uses current spread snapshot', (
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
      final previousSpread = await spreadImage(
        const Color(0xFF8E24AA),
        const Color(0xFF6D4C41),
      );
      addTearDown(currentSpread.dispose);
      addTearDown(previousSpread.dispose);

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
                touchPosition: const Offset(50, 150),
                pageSnapshots: const {},
                spreadSnapshots: {0: previousSpread, 1: currentSpread},
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

      final openClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
      );
      expect(openClipper, findsOneWidget);
      final middleImages = tester
          .widgetList<RawImage>(
            find.descendant(
              of: openClipper,
              matching: find.byType(RawImage),
            ),
          )
          .map((w) => w.image)
          .toList();
      expect(middleImages, contains(currentSpread));
      expect(middleImages, isNot(contains(previousSpread)));
    });

    testWidgets(
      'backward double-spread: bottom uses clipper, middle uses open clipper',
      (tester) async {
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
        final previousSpread = await spreadImage(
          const Color(0xFF8E24AA),
          const Color(0xFF6D4C41),
        );
        addTearDown(currentSpread.dispose);
        addTearDown(previousSpread.dispose);

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
                  touchPosition: const Offset(50, 150),
                  pageSnapshots: const {},
                  spreadSnapshots: {0: previousSpread, 1: currentSpread},
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

        final clipper = find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipClipper,
        );
        expect(clipper, findsOneWidget);

        final openClipper = find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
        );
        expect(openClipper, findsOneWidget);

        final middleImage = tester.widget<RawImage>(
          find.descendant(
            of: openClipper,
            matching: find.byType(RawImage),
          ),
        );
        expect(middleImage.image, equals(currentSpread));
        expect(middleImage.image, isNot(equals(previousSpread)));
      },
    );

    testWidgets('backward drag keeps previous page in Offstage pre-render', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpSinglePageLayerView(
          dragProgress: 0.85,
          isForward: false,
          currentIndex: 1,
        ),
      );

      // Page 0 is now in Offstage pre-render (was previously skipped).
    });

    testWidgets('forward bottom layer uses next page snapshot not live widget',
        (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 300),
        Paint()..color = const Color(0xFF43A047),
      );
      final nextSnapshot = await recorder.endRecording().toImage(400, 300);
      addTearDown(nextSnapshot.dispose);

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
                pageSnapshots: {2: nextSnapshot},
                spreadSnapshots: const {},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                itemBuilder: (context, index) => Text('Page $index'),
              ),
            ),
          ),
        ),
      );

      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
      );
      final bottomImage = tester.widget<RawImage>(
        find.descendant(
          of: bottomClipper,
          matching: find.byType(RawImage),
        ),
      );
      expect(bottomImage.image, equals(nextSnapshot));
      expect(
        find.descendant(of: bottomClipper, matching: find.text('Page 2')),
        findsNothing,
      );
    });

    testWidgets(
        'backward bottom layer uses current page snapshot not live widget', (
      tester,
    ) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 400, 300),
        Paint()..color = const Color(0xFF1E88E5),
      );
      final currentSnapshot = await recorder.endRecording().toImage(400, 300);
      addTearDown(currentSnapshot.dispose);

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
                touchPosition: const Offset(50, 150),
                pageSnapshots: {1: currentSnapshot},
                spreadSnapshots: const {},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                paperFlapColor: const Color(0xFFF5F5F5),
                itemBuilder: (context, index) => Text('Page $index'),
              ),
            ),
          ),
        ),
      );

      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
      );
      final bottomImage = tester.widget<RawImage>(
        find.descendant(
          of: bottomClipper,
          matching: find.byType(RawImage),
        ),
      );
      expect(bottomImage.image, equals(currentSnapshot));
      expect(
        find.descendant(of: bottomClipper, matching: find.text('Page 1')),
        findsNothing,
      );
    });

    testWidgets('flip layers use opaque paper fallback when snapshot missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumpSinglePageLayerView(
          dragProgress: 0.85,
          isForward: true,
          currentIndex: 1,
        ),
      );

      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
      );
      // Opaque paper fallback shows up instead of live widget to avoid GlobalKey conflicts.
      expect(
        find.descendant(of: bottomClipper, matching: find.text('Page 2')),
        findsNothing,
      );
    });
  });

  group('PageFlipLayerView double-spread bottom layer', () {
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

    Finder bottomOpenClipper() => find
        .byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipOpenClipper,
        )
        .at(0);

    testWidgets('forward bottom layer clips next spread right half', (
      tester,
    ) async {
      final nextSpread = await spreadImage(
        const Color(0xFF43A047),
        const Color(0xFFFFB300),
      );
      addTearDown(nextSpread.dispose);

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
                spreadSnapshots: {2: nextSpread},
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

      final bottomAlign = tester.widget<Align>(
        find.descendant(
          of: bottomOpenClipper(),
          matching: find.byWidgetPredicate(
            (w) => w is Align && w.widthFactor == 0.5,
          ),
        ),
      );
      expect(bottomAlign.alignment, Alignment.centerRight);
      expect(
        find.descendant(
          of: bottomOpenClipper(),
          matching: find.byType(FractionallySizedBox),
        ),
        findsNothing,
      );

      final bottomImage = tester.widget<RawImage>(
        find.descendant(
          of: bottomOpenClipper(),
          matching: find.byType(RawImage),
        ),
      );
      expect(bottomImage.image, equals(nextSpread));
    });

    testWidgets('backward bottom layer clips previous spread left half', (
      tester,
    ) async {
      const previousLeft = Color(0xFF8E24AA);
      final currentSpread = await spreadImage(
        const Color(0xFFE53935),
        const Color(0xFF1E88E5),
      );
      final previousSpread = await spreadImage(
        previousLeft,
        const Color(0xFF6D4C41),
      );
      addTearDown(currentSpread.dispose);
      addTearDown(previousSpread.dispose);

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
                touchPosition: const Offset(50, 150),
                pageSnapshots: const {},
                spreadSnapshots: {0: previousSpread, 1: currentSpread},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => ColoredBox(
                  color: Colors.primaries[index % Colors.primaries.length],
                  child: Center(child: Text('Spread $index')),
                ),
              ),
            ),
          ),
        ),
      );

      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      expect(bottomClipper, findsOneWidget);

      final bottomAlign = tester.widget<Align>(
        find.descendant(
          of: bottomClipper,
          matching: find.byWidgetPredicate(
            (w) => w is Align && w.widthFactor == 0.5,
          ),
        ),
      );
      expect(bottomAlign.alignment, Alignment.centerLeft);
      expect(
        find.descendant(
          of: bottomClipper,
          matching: find.byType(FractionallySizedBox),
        ),
        findsNothing,
      );

      final bottomImage = tester.widget<RawImage>(
        find.descendant(
          of: bottomClipper,
          matching: find.byType(RawImage),
        ),
      );
      expect(bottomImage.image, equals(previousSpread));
      expect(bottomImage.image, isNot(equals(currentSpread)));
    });

    testWidgets('forward middle layer clips current spread left half', (
      tester,
    ) async {
      final currentSpread = await spreadImage(
        const Color(0xFFE53935),
        const Color(0xFF1E88E5),
      );
      addTearDown(currentSpread.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: 0.5,
                isDragging: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                pageSnapshots: const {},
                spreadSnapshots: {1: currentSpread},
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

      final middleClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      expect(middleClipper, findsOneWidget);

      final middleAlign = tester.widget<Align>(
        find.descendant(
          of: middleClipper,
          matching: find.byWidgetPredicate(
            (w) => w is Align && w.widthFactor == 0.5,
          ),
        ),
      );
      expect(middleAlign.alignment, Alignment.centerLeft);

      final middleImage = tester.widget<RawImage>(
        find.descendant(
          of: middleClipper,
          matching: find.byType(RawImage),
        ),
      );
      expect(middleImage.image, equals(currentSpread));
    });

    testWidgets('double spread forward keeps OffscreenPreRenderer current for capture', (
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
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is OffscreenPreRenderer && w.isOffscreen,
        ),
        findsWidgets,
      );
      expect(
        find.byKey(currentKey, skipOffstage: false),
        findsOneWidget,
      );
    });

    // ─── Backward double-spread ───

    testWidgets('backward middle layer does NOT clip to half', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 5,
                currentIndex: 3,
                dragProgress: 0.75,
                isDragging: true,
                isForward: false,
                touchPosition: const Offset(80, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: {3: GlobalKey(), 2: GlobalKey(), 4: GlobalKey()},
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      // Middle layer should NOT have Align with widthFactor=0.5 (no half-clip)
      final halfAligns = find.byWidgetPredicate(
        (w) => w is Align && w.widthFactor == 0.5,
      );
      // There should be exactly 1 half-Align (for the bottom layer),
      // not 2 (no half-clip for middle layer in backward mode)
      expect(halfAligns, findsOneWidget);
    });

    testWidgets('backward double-spread at index 0 shows paper fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 0,
                dragProgress: 0.3,
                isDragging: true,
                isForward: false,
                touchPosition: const Offset(60, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: const {},
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      // Bottom layer falls back to ColoredBox paper (no previous spread)
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('backward double-spread with opaque paper fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 5,
                currentIndex: 2,
                dragProgress: 0.6,
                isDragging: true,
                isForward: false,
                touchPosition: const Offset(70, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: {0: GlobalKey(), 1: GlobalKey(), 2: GlobalKey()},
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      final bottomClipper = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is PageFlipClipper,
      );
      // Bottom layer with spread 1 should NOT show live Page 0 and Page 1 content (opaque paper fallback)
      expect(find.descendant(of: bottomClipper, matching: find.text('Spread 1')), findsNothing);
      // Middle layer references spread 2
      expect(find.text('Spread 2'), findsWidgets);
    });

    testWidgets('backward double-spread offscreen renderer includes adjacent indices', (
      tester,
    ) async {
      final keys = <int, GlobalKey>{
        0: GlobalKey(),
        1: GlobalKey(),
        2: GlobalKey(),
        3: GlobalKey(),
        4: GlobalKey(),
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 5,
                currentIndex: 2,
                dragProgress: 0.5,
                isDragging: true,
                isForward: false,
                touchPosition: const Offset(100, 150),
                pageSnapshots: const {},
                spreadSnapshots: const {},
                pageKeys: keys,
                constrainedSize: canvasSize,
                isDoubleSpread: true,
                itemBuilder: (context, index) => Text('Spread $index'),
              ),
            ),
          ),
        ),
      );

      // OffscreenPreRenderer: background indices 1,3 + currentPage + MaterialApp internals
      // At minimum the two background OffscreenPreRenderer widgets must exist
      expect(
        find.byWidgetPredicate((w) => w is OffscreenPreRenderer),
        findsAtLeast(2),
      );

      // Adjacent indices (1, 3) are findable via their keys
      expect(find.byKey(keys[1]!, skipOffstage: true), findsOneWidget);
      expect(find.byKey(keys[3]!, skipOffstage: true), findsOneWidget);

      // Non-adjacent index 0 should have no OffscreenPreRenderer in the tree
      expect(find.byKey(keys[0]!, skipOffstage: true), findsNothing);
    });
  });
}
