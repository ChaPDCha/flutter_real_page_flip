import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

// ⚠️ PROVISIONAL BASELINES — read before trusting these goldens.
//
// Golden files only assert "pixels match the last capture". They do NOT judge
// whether the flip *looks* good. The baselines committed here are therefore
// only a regression lock for the LAST RENDERED state, which is not necessarily
// the visually-approved target.
//
// Workflow agreed with the product owner:
//   1. Until the look is approved on a real device, the meaningful gate is the
//      invariant + coverage tests (e.g. "no uncovered gap on any backward
//      frame", middleLayerOpacity monotonicity), NOT these goldens.
//   2. Once the on-device look is approved, re-freeze these goldens ONCE with
//      `--update-goldens`; from then on they guard the approved appearance.
//
// Pages render realistic body text (not solid color blocks) so the captured
// flap curvature, paper highlight, and fold shadow interact with real glyphs —
// the qualities a solid block can never reveal.
void main() {
  const canvasSize = Size(400, 300);
  const paper = Color(0xFFF7F1E3); // warm Bible paper
  const ink = Color(0xFF2B2620);

  late GoldenFileComparator previousGoldenFileComparator;

  setUpAll(() {
    previousGoldenFileComparator = goldenFileComparator;
    // These provisional goldens exercise paper/shadow shape, not exact glyph
    // rasterization. Linux CI and Windows local Skia can differ by a few dozen
    // edge pixels, so keep a tight tolerance while still catching real drift.
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/page_flip_layer_view_golden_test.dart'),
      precisionTolerance: 0.001,
    );
  });

  tearDownAll(() {
    goldenFileComparator = previousGoldenFileComparator;
  });

  /// Renders a realistic single text page (title + wrapped body) to an image
  /// so goldens exercise how the flip treats actual content.
  Future<ui.Image> textPageImage({
    required String title,
    required String body,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = canvasSize.width;
    final h = canvasSize.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = paper);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: ink,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 48);
    titlePainter.paint(canvas, const Offset(24, 22));

    final bodyPainter = TextPainter(
      text: TextSpan(
        text: body,
        style: const TextStyle(
          color: ink,
          fontSize: 12.5,
          height: 1.55,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 48);
    bodyPainter.paint(canvas, const Offset(24, 56));

    return recorder.endRecording().toImage(w.toInt(), h.toInt());
  }

  group('PageFlipLayerView golden — single page reveal', () {
    late ui.Image currentPage;
    late ui.Image nextPage;
    late ui.Image previousPage;

    setUp(() async {
      currentPage = await textPageImage(
        title: 'Genesis 1',
        body: '1 In the beginning God created the heavens and the earth. '
            '2 Now the earth was formless and empty, darkness was over the '
            'surface of the deep, and the Spirit of God was hovering over '
            'the waters. 3 And God said, "Let there be light," and there '
            'was light.',
      );
      nextPage = await textPageImage(
        title: 'Genesis 2',
        body: '1 Thus the heavens and the earth were completed in all their '
            'vast array. 2 By the seventh day God had finished the work he '
            'had been doing; so on the seventh day he rested from all his '
            'work. 3 Then God blessed the seventh day and made it holy.',
      );
      previousPage = await textPageImage(
        title: 'Psalm 150',
        body: '1 Praise the LORD. Praise God in his sanctuary; praise him in '
            'his mighty heavens. 2 Praise him for his acts of power; praise '
            'him for his surpassing greatness. 3 Praise him with the sounding '
            'of the trumpet, praise him with the harp and lyre.',
      );
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
    }) =>
        MaterialApp(
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
                  paperFlapColor: const Color(0xFFF5F5F5),
                  itemBuilder: (context, index) => ColoredBox(
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                ),
              ),
            ),
          ),
        );

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

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  })  : assert(
          0 <= precisionTolerance && precisionTolerance <= 1,
          'precisionTolerance must be between 0 and 1',
        ),
        _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
