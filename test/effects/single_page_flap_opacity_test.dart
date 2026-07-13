import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Regression: the single-page flap must be an OPAQUE sheet.
///
/// The thin-paper `saveLayer` used to composite the whole flap (opaque paper
/// underlay included) at ~85% alpha mid-flip. Under the flap sits the
/// stationary middle layer — the current page in its original, un-mirrored
/// position — so it bled through in place. On screen that read as three hard
/// vertical bands (full-bright middle | washed flap | crisp revealed page):
/// "the turning page splits into three stacked sheets".
///
/// Probe: the current page is BLUE on its left half and paper on its right
/// half. At p=0.5 forward the flap's own peeled strip is the page's RIGHT half
/// (pure paper), while the middle layer beneath the flap is BLUE. Any blue
/// tint inside the flap region can therefore only come from the middle
/// bleeding through a translucent flap.
void main() {
  const paper = Color(0xFFFAF6ED); // B < R (warm paper)
  const blue = Color(0xFF3060E0); // B >> R
  const green = Color(0xFF30A050);

  Future<ui.Image> halfBluePage(Size size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width / 2, size.height),
      Paint()..color = blue,
    );
    return recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  Future<ui.Image> solidPage(Size size, Color color) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    return recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  /// Renders the full compositing stack and returns (B − R) channel averages
  /// sampled at three probe columns: middle band, flap centre, revealed band.
  Future<({double middle, double flap, double revealed})> probe(
    WidgetTester tester, {
    required DevicePerformanceProfile profile,
    required double dragProgress,
  }) async {
    const canvasSize = Size(1000, 800);
    tester.view.physicalSize = canvasSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pageA = await solidPage(canvasSize, paper);
    final pageB = await halfBluePage(canvasSize); // current
    final pageC = await solidPage(canvasSize, green); // next
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
                touchPosition: const Offset(500, 400),
                pageSnapshots: {0: pageA, 2: pageC},
                spreadSnapshots: {1: pageB},
                pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
                constrainedSize: canvasSize,
                paperFlapColor: paper,
                // Engine default the host inherits — the value that produced
                // the translucent-flap artifact before the fix.
                thinPaperStrength: 0.15,
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
    late final ({double middle, double flap, double revealed}) result;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bd = await image.toByteData();
      final px = bd!.buffer.asUint8List();
      final w = image.width;

      double bMinusR(int x0, int x1) {
        var sum = 0.0;
        var n = 0;
        for (var y = 300; y <= 500; y += 10) {
          for (var x = x0; x <= x1; x += 10) {
            final i = (y * w + x) * 4;
            sum += px[i + 2] - px[i]; // RGBA order: R at +0, B at +2
            n++;
          }
        }
        return sum / n;
      }

      // p=0.5, w=1000: fold=500, flapVisible≈350 → flap ≈ [150..500].
      // Middle band: x<150 (blue). Flap centre: 220..430. Revealed: 540..900.
      result = (
        middle: bMinusR(40, 120),
        flap: bMinusR(220, 430),
        revealed: bMinusR(540, 900),
      );
      image.dispose();
    });
    return result;
  }

  for (final profile in [
    DevicePerformanceProfile.high,
    DevicePerformanceProfile.medium,
    DevicePerformanceProfile.low,
  ]) {
    testWidgets(
        'flap shows NO middle-layer bleed-through at mid-flip ($profile)',
        (tester) async {
      final bands = await probe(tester, profile: profile, dragProgress: 0.5);

      // Sanity: the probe geometry is what we think it is.
      expect(
        bands.middle,
        greaterThan(100),
        reason: 'Left of the free edge the BLUE middle layer must be visible '
            '(probe sanity check)',
      );
      expect(
        bands.revealed,
        lessThan(60),
        reason: 'Right of the fold the revealed page (green/paper mix) must '
            'not read as blue (probe sanity check)',
      );

      // The core assertion: inside the flap, the peeled strip is pure paper
      // (B−R ≈ −13). Any positive B−R means the BLUE middle layer is bleeding
      // through a translucent flap — the three-sheet artifact.
      expect(
        bands.flap,
        lessThan(0),
        reason:
            'Blue tint inside the flap (B−R=${bands.flap.toStringAsFixed(1)}) '
            'means the stationary middle layer is visible THROUGH the flap — '
            'the single-page sheet must be opaque',
      );
    });
  }
}
