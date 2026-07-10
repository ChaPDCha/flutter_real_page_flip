import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Regression: gradients in [PageFlipPainter] must never fade toward
/// `Colors.transparent` (transparent BLACK). Flutter's gradient lerps RGB
/// channels toward black as alpha falls, so a light-paper mask fading to
/// transparent black paints a semi-opaque DARK GRAY halo mid-ramp — two hard
/// dark "pillars" hugging the flap's free edge and fold line (lum ~166-190 on
/// 247 paper, i.e. 25-35% darkening where at most ~15% intended shading
/// exists). Every gradient endpoint must be the same hue at alpha 0.
///
/// This renders a flip over PLAIN light paper (no text) and asserts no pixel
/// anywhere drops below the darkest INTENDED shading (crease valley ~15% +
/// small stacking margin). The halo bug fails this by a wide margin.
void main() {
  const paper = Color(0xFFFAF6ED); // paper luminance ≈ 247

  Future<ui.Image> plainPaper(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    return recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  Future<int> minLuminance(
    WidgetTester tester, {
    required Size canvasSize,
    required double dragProgress,
    required Offset touch,
    required DevicePerformanceProfile profile,
  }) async {
    tester.view.physicalSize = canvasSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pageA = await plainPaper(canvasSize);
    final pageB = await plainPaper(canvasSize);
    final pageC = await plainPaper(canvasSize);
    addTearDown(pageA.dispose);
    addTearDown(pageB.dispose);
    addTearDown(pageC.dispose);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: paper),
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox.fromSize(
              size: canvasSize,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: dragProgress,
                isDragging: true,
                isForward: true,
                touchPosition: touch,
                pageSnapshots: {0: pageA, 2: pageC},
                spreadSnapshots: {1: pageB},
                pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
                constrainedSize: canvasSize,
                paperFlapColor: paper,
                singlePageBackContentOpacity: 0.35,
                performanceProfile: profile,
                itemBuilder: (context, index) => const ColoredBox(color: paper),
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
    var min = 255;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bd = await image.toByteData();
      final px = bd!.buffer.asUint8List();
      final w = image.width;
      final h = image.height;
      // Sample a grid (every 2px) — dense enough to catch a >=2px-wide halo.
      for (var y = 0; y < h; y += 2) {
        for (var x = 0; x < w; x += 2) {
          final v = px[(y * w + x) * 4];
          if (v < min) min = v;
        }
      }
      image.dispose();
    });
    return min;
  }

  // Darkest INTENDED shading on 247 paper: crease valley (15%) possibly
  // overlapping the fold-darken hairline (5%) → ~200. The halo bug measured
  // 166-190. 195 cleanly separates intended shading from the halo artifact.
  const floorLum = 195;

  group('no dark-pillar gradient halo on plain light paper', () {
    for (final profile in DevicePerformanceProfile.values) {
      testWidgets('mid-flip centered ($profile)', (tester) async {
        final min = await minLuminance(
          tester,
          canvasSize: const Size(900, 800),
          dragProgress: 0.54,
          touch: const Offset(420, 400),
          profile: profile,
        );
        expect(
          min,
          greaterThanOrEqualTo(floorLum),
          reason: 'A pixel darker than any intended shading (min lum $min) '
              'indicates a gradient fading to transparent BLACK — the dark '
              'pillar halo at the flap boundaries.',
        );
      });
    }

    testWidgets('early drag, high profile', (tester) async {
      final min = await minLuminance(
        tester,
        canvasSize: const Size(900, 800),
        dragProgress: 0.25,
        touch: const Offset(600, 200),
        profile: DevicePerformanceProfile.high,
      );
      expect(min, greaterThanOrEqualTo(floorLum));
    });

    testWidgets('late drag, angled touch, high profile', (tester) async {
      final min = await minLuminance(
        tester,
        canvasSize: const Size(900, 800),
        dragProgress: 0.8,
        touch: const Offset(150, 780),
        profile: DevicePerformanceProfile.high,
      );
      expect(min, greaterThanOrEqualTo(floorLum));
    });
  });
}
