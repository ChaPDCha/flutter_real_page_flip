import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Regression: in single-page mode the BACKWARD (previous-page) flip must be a
/// true time-reverse of the FORWARD flip — the crease sits on the LEFT and the
/// flap peels leftward, revealing the destination page on the RIGHT of the fold.
///
/// The old behaviour reused the double-spread "spine" geometry (crease on the
/// RIGHT, flap extending right), which looked like a mirrored 2-page turn. With
/// that geometry the right-of-centre region shows the *peeling* page (previous);
/// with the corrected reverse-of-forward geometry it shows the *revealed*
/// destination page (current). We assert the latter via a pixel probe.
void main() {
  const canvasSize = Size(400, 300);

  // Distinct, easily separable hues for each page slot.
  const prevColor = Color(0xFF8E24AA); // purple  (previous page)
  const currColor = Color(0xFF2962FF); // blue    (current page)
  const nextColor = Color(0xFF00C853); // green   (next page)

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

  /// Renders one flip frame and returns the RGBA pixel at ([fx]·w, [fy]·h).
  Future<List<int>> probePixel(
    WidgetTester tester, {
    required bool isForward,
    required double dragProgress,
    required Map<int, ui.Image> snaps,
    required double fx,
    required double fy,
  }) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox.fromSize(
                size: canvasSize,
                child: PageFlipLayerView(
                  itemCount: 3,
                  currentIndex: 1,
                  dragProgress: dragProgress,
                  isDragging: true,
                  isForward: isForward,
                  // Straight (non-tilted) fold keeps the probe deterministic.
                  touchPosition: const Offset(200, 150),
                  pageSnapshots: snaps,
                  spreadSnapshots: const {},
                  pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
                  constrainedSize: canvasSize,
                  paperFlapColor: const Color(0xFFF5F5F5),
                  itemBuilder: (context, index) =>
                      const ColoredBox(color: Color(0xFFF5F5F5)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    ByteData? data;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      data = await image.toByteData();
      image.dispose();
    });
    final pixels = data!.buffer.asUint8List();
    final px = (fx * width).round().clamp(0, width - 1);
    final py = (fy * (canvasSize.height) * (width / canvasSize.width)).round();
    final idx = (py * width + px) * 4;
    return [pixels[idx], pixels[idx + 1], pixels[idx + 2]];
  }

  int dist(List<int> a, Color b) {
    final dr = a[0] - ((b.toARGB32() >> 16) & 0xFF);
    final dg = a[1] - ((b.toARGB32() >> 8) & 0xFF);
    final db = a[2] - (b.toARGB32() & 0xFF);
    return dr * dr + dg * dg + db * db;
  }

  testWidgets(
      'single backward reveals CURRENT page right of centre (reverse-of-forward)',
      (tester) async {
    final prev = await solid(prevColor);
    final curr = await solid(currColor);
    addTearDown(prev.dispose);
    addTearDown(curr.dispose);

    // Probe right of the centre fold (x = 0.72w). In reverse-of-forward the
    // flap peels LEFT, so this region is the revealed CURRENT page, not the
    // peeling PREVIOUS page (which the old mirror geometry would have shown).
    final rgb = await probePixel(
      tester,
      isForward: false,
      dragProgress: 0.5,
      snaps: {0: prev, 1: curr},
      fx: 0.72,
      fy: 0.5,
    );

    final toCurrent = dist(rgb, currColor);
    final toPrevious = dist(rgb, prevColor);
    expect(
      toCurrent < toPrevious,
      isTrue,
      reason: 'right-of-fold should show the revealed current page (blue), not '
          'the peeling previous page (purple). rgb=$rgb',
    );
  });

  testWidgets('single forward reveals NEXT page right of centre (baseline)',
      (tester) async {
    final curr = await solid(currColor);
    final next = await solid(nextColor);
    addTearDown(curr.dispose);
    addTearDown(next.dispose);

    final rgb = await probePixel(
      tester,
      isForward: true,
      dragProgress: 0.5,
      snaps: {1: curr, 2: next},
      fx: 0.72,
      fy: 0.5,
    );

    expect(
      dist(rgb, nextColor) < dist(rgb, currColor),
      isTrue,
      reason:
          'right-of-fold should show the revealed next page (green). rgb=$rgb',
    );
  });
}
