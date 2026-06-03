import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  const canvasSize = Size(400, 300);

  Future<ui.Image> createSpreadImage({
    required Color left,
    required Color right,
  }) async {
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
    final picture = recorder.endRecording();
    return picture.toImage(
      canvasSize.width.toInt(),
      canvasSize.height.toInt(),
    );
  }

  Future<Map<int, ui.Image>> buildSpreadSnapshots() async {
    final current = await createSpreadImage(
      left: const Color(0xFFE53935),
      right: const Color(0xFF1E88E5),
    );
    final next = await createSpreadImage(
      left: const Color(0xFF43A047),
      right: const Color(0xFFFFB300),
    );
    final previous = await createSpreadImage(
      left: const Color(0xFF8E24AA),
      right: const Color(0xFF6D4C41),
    );
    return {0: previous, 1: current, 2: next};
  }

  Widget goldenLayerView({
    required double dragProgress,
    required bool isForward,
    required int currentIndex,
    required Map<int, ui.Image> spreadSnapshots,
  }) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: SizedBox.fromSize(
            size: canvasSize,
            child: PageFlipLayerView(
              itemCount: 3,
              currentIndex: currentIndex,
              dragProgress: dragProgress,
              isDragging: true,
              isForward: isForward,
              touchPosition: isForward
                  ? const Offset(350, 150)
                  : const Offset(50, 150),
              pageSnapshots: const {},
              spreadSnapshots: spreadSnapshots,
              pageKeys: {
                for (var i = 0; i < 3; i++) i: GlobalKey(),
              },
              constrainedSize: canvasSize,
              isDoubleSpread: true,
              paperFlapColor: const Color(0xFFF5F5F5),
              itemBuilder: (context, index) => ColoredBox(
                color: Colors.primaries[index % Colors.primaries.length],
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('PageFlipLayerView golden — double spread spine reveal', () {
    late Map<int, ui.Image> spreads;

    setUp(() async {
      spreads = await buildSpreadSnapshots();
    });

    tearDown(() {
      for (final image in spreads.values) {
        image.dispose();
      }
    });

    testWidgets('forward progress 0.5', (tester) async {
      await tester.pumpWidget(
        goldenLayerView(
          dragProgress: 0.5,
          isForward: true,
          currentIndex: 1,
          spreadSnapshots: spreads,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/spine_reveal_forward_050.png'),
      );
    });

    testWidgets('forward progress 0.85', (tester) async {
      await tester.pumpWidget(
        goldenLayerView(
          dragProgress: 0.85,
          isForward: true,
          currentIndex: 1,
          spreadSnapshots: spreads,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/spine_reveal_forward_085.png'),
      );
    });

    testWidgets('forward progress 0.92', (tester) async {
      await tester.pumpWidget(
        goldenLayerView(
          dragProgress: 0.92,
          isForward: true,
          currentIndex: 1,
          spreadSnapshots: spreads,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/spine_reveal_forward_092.png'),
      );
    });

    testWidgets('backward progress 0.85', (tester) async {
      await tester.pumpWidget(
        goldenLayerView(
          dragProgress: 0.85,
          isForward: false,
          currentIndex: 1,
          spreadSnapshots: spreads,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/spine_reveal_backward_085.png'),
      );
    });

    testWidgets('backward progress 0.92', (tester) async {
      await tester.pumpWidget(
        goldenLayerView(
          dragProgress: 0.92,
          isForward: false,
          currentIndex: 1,
          spreadSnapshots: spreads,
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/spine_reveal_backward_092.png'),
      );
    });
  });

  group('PageFlipLayerView golden — single page reveal', () {
    late ui.Image currentPage;
    late ui.Image nextPage;
    late ui.Image previousPage;

    setUp(() async {
      Future<ui.Image> solid(Color color) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
          Paint()..color = color,
        );
        return recorder.endRecording().toImage(
              canvasSize.width.toInt(),
              canvasSize.height.toInt(),
            );
      }

      currentPage = await solid(const Color(0xFF1E88E5));
      nextPage = await solid(const Color(0xFF43A047));
      previousPage = await solid(const Color(0xFF8E24AA));
    });

    tearDown(() {
      currentPage.dispose();
      nextPage.dispose();
      previousPage.dispose();
    });

    Widget goldenSinglePageView({
      required double dragProgress,
      required bool isForward,
      required int currentIndex,
      required Map<int, ui.Image> pageSnapshots,
    }) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Center(
            child: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: currentIndex,
                dragProgress: dragProgress,
                isDragging: true,
                isForward: isForward,
                touchPosition: isForward
                    ? const Offset(350, 150)
                    : const Offset(50, 150),
                pageSnapshots: pageSnapshots,
                spreadSnapshots: const {},
                pageKeys: {
                  for (var i = 0; i < 3; i++) i: GlobalKey(),
                },
                constrainedSize: canvasSize,
                isDoubleSpread: false,
                paperFlapColor: const Color(0xFFF5F5F5),
                itemBuilder: (context, index) => ColoredBox(
                  color: Colors.primaries[index % Colors.primaries.length],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('forward progress 0.50', (tester) async {
      await tester.pumpWidget(
        goldenSinglePageView(
          dragProgress: 0.5,
          isForward: true,
          currentIndex: 1,
          pageSnapshots: {1: currentPage, 2: nextPage},
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/single_page_reveal_forward_050.png'),
      );
    });

    testWidgets('backward progress 0.50', (tester) async {
      await tester.pumpWidget(
        goldenSinglePageView(
          dragProgress: 0.5,
          isForward: false,
          currentIndex: 1,
          pageSnapshots: {0: previousPage, 1: currentPage},
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/single_page_reveal_backward_050.png'),
      );
    });

    testWidgets('forward progress 0.85', (tester) async {
      await tester.pumpWidget(
        goldenSinglePageView(
          dragProgress: 0.85,
          isForward: true,
          currentIndex: 1,
          pageSnapshots: {1: currentPage, 2: nextPage},
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/single_page_reveal_forward_085.png'),
      );
    });

    testWidgets('backward progress 0.85', (tester) async {
      await tester.pumpWidget(
        goldenSinglePageView(
          dragProgress: 0.85,
          isForward: false,
          currentIndex: 1,
          pageSnapshots: {0: previousPage, 1: currentPage},
        ),
      );
      await tester.pump();

      await expectLater(
        find.byType(PageFlipLayerView),
        matchesGoldenFile('goldens/single_page_reveal_backward_085.png'),
      );
    });
  });
}
