import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Regression: the single-page fold crease must read as ONE continuous dark
/// line at every fold angle. The flap's fold boundary is a curved bezier that
/// bulges toward the revealed side, so the revealed page peeks through in a
/// crescent next to the crease. If the revealed-page shadow is anchored only at
/// the straight foldX, that crescent stays bright and — at an angle — shows up
/// as a diagonal "blade" between the flap's crease shadow and the revealed-page
/// shadow. This test renders a uniform-grey flip and asserts there is no bright
/// sliver sandwiched between two darker bands across the fold.
void main() {
  const canvasSize = Size(400, 300);
  const grey = Color(0xFF808080);

  Future<ui.Image> solidGrey() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..color = grey,
    );
    return recorder.endRecording().toImage(
          canvasSize.width.toInt(),
          canvasSize.height.toInt(),
        );
  }

  /// Returns the worst "blade" depth found across sampled rows: the luminance
  /// rise (bright sliver) that sits between two darker bands near the fold.
  /// 0 means no bright sliver (good). A large value means a visible blade.
  Future<int> maxBladeRise(
    WidgetTester tester, {
    required bool isForward,
    required double dragProgress,
    required Offset touch,
  }) async {
    final pageA = await solidGrey();
    final pageB = await solidGrey();
    addTearDown(pageA.dispose);
    addTearDown(pageB.dispose);

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
                  touchPosition: touch,
                  pageSnapshots:
                      isForward ? {1: pageB, 2: pageA} : {0: pageA, 1: pageB},
                  spreadSnapshots: const {},
                  pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
                  constrainedSize: canvasSize,
                  paperFlapColor: grey,
                  itemBuilder: (context, index) => const ColoredBox(color: grey),
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
    ByteData? bd;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      bd = await image.toByteData();
      image.dispose();
    });
    final px = bd!.buffer.asUint8List();
    final w = canvasSize.width.toInt();
    int lum(int x, int y) => px[(y * w + x) * 4];

    final foldX = isForward
        ? (400 * (1 - dragProgress)).round()
        : (400 * (1 - dragProgress)).round();

    var worst = 0;
    for (final y in [10, 40, 80, 150, 220, 260, 290]) {
      // Scan a window around the fold for the pattern dark → bright → dark.
      const half = 45;
      final lo = (foldX - half).clamp(0, w - 1);
      final hi = (foldX + half).clamp(0, w - 1);
      // Darkest luminance in window (the crease).
      var darkest = 255;
      for (var x = lo; x <= hi; x++) {
        final v = lum(x, y);
        if (v < darkest) darkest = v;
      }
      // A band counts as "shadow" if clearly darker than base grey (128).
      const shadowMax = 122; // <= base-6
      const brightMin = 126; // >= base-2 (essentially un-shadowed)
      // Walk the window; whenever we are inside shadow, cross a bright run, and
      // re-enter shadow, the bright run is a blade. Record its rise.
      var i = lo;
      var seenShadow = false;
      while (i <= hi) {
        final v = lum(i, y);
        if (v <= shadowMax) {
          seenShadow = true;
          i++;
          continue;
        }
        if (v >= brightMin && seenShadow) {
          // Start of a candidate bright run; measure it and peek past it.
          var j = i;
          var peak = 0;
          while (j <= hi && lum(j, y) >= brightMin) {
            peak = peak < lum(j, y) - darkest ? lum(j, y) - darkest : peak;
            j++;
          }
          // Is there shadow again after the bright run? Then it's a blade.
          if (j <= hi && lum(j, y) <= shadowMax) {
            if (peak > worst) worst = peak;
          }
          i = j;
          continue;
        }
        i++;
      }
    }
    return worst;
  }

  group('single-page fold crease has no bright blade', () {
    final cases = <(String, bool, double, Offset)>[
      ('forward centered p=0.5', true, 0.5, const Offset(350, 150)),
      ('forward top-tilt p=0.5', true, 0.5, const Offset(350, 0)),
      ('forward bottom-tilt p=0.5', true, 0.5, const Offset(350, 300)),
      ('forward top-tilt p=0.3', true, 0.3, const Offset(350, 0)),
      ('forward top-tilt p=0.7', true, 0.7, const Offset(350, 0)),
      ('backward centered p=0.5', false, 0.5, const Offset(50, 150)),
      ('backward top-tilt p=0.5', false, 0.5, const Offset(50, 0)),
      ('backward bottom-tilt p=0.5', false, 0.5, const Offset(50, 300)),
    ];

    for (final (name, isForward, p, touch) in cases) {
      testWidgets(name, (tester) async {
        final rise = await maxBladeRise(
          tester,
          isForward: isForward,
          dragProgress: p,
          touch: touch,
        );
        expect(
          rise,
          lessThanOrEqualTo(6),
          reason: 'A bright sliver (rise=$rise) appeared between two crease '
              'shadow bands — the fold "blade" artifact.',
        );
      });
    }
  });
}
