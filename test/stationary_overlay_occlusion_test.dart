import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/effects/page_flip_painter.dart';

/// Records what the engine let it paint, so a test can ask WHERE the host's
/// stationary decoration actually landed rather than eyeballing a golden.
///
/// Fills the whole viewport, so any pixel that comes back unpainted is a pixel
/// the engine deliberately clipped away — which is the entire property under
/// test.
class _FloodPainter extends CustomPainter {
  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount++;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF000000),
    );
  }

  @override
  bool shouldRepaint(covariant _FloodPainter oldDelegate) => false;
}

Future<ui.Image> _renderPainter(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = const Color(0xFFFFFFFF),
  );
  painter.paint(canvas, size);
  return recorder.endRecording().toImage(
        size.width.round(),
        size.height.round(),
      );
}

/// Fraction of pixels the host overlay actually darkened.
///
/// MUST be awaited inside `tester.runAsync`: `toImage` completes on the real
/// event loop, which `testWidgets`' fake-async zone never pumps — call it
/// directly and the test hangs until the suite times out rather than failing.
Future<double> _coverage(CustomPainter painter, Size size) async {
  final image = await _renderPainter(painter, size);
  final bytes = await image.toByteData();
  image.dispose();
  if (bytes == null) return 0;

  var covered = 0;
  final total = size.width.round() * size.height.round();
  for (var i = 0; i < total; i++) {
    if (bytes.getUint8(i * 4) < 128) covered++;
  }
  return covered / total;
}

PageFlipPainter _painterAt(
  double progress, {
  required CustomPainter overlay,
  required Size size,
}) =>
    PageFlipPainter(
      progress: progress,
      isRightToLeft: true,
      touchOffset: Offset(size.width * 0.9, size.height / 2),
      paperBackColor: const Color(0xFFFFFFFF),
      isDoubleSpread: true,
      stationaryOverlayPainter: overlay,
    );

void main() {
  const size = Size(400, 300);

  group('stationaryOverlayPainter — the turning sheet occludes host chrome',
      () {
    testWidgets('mid-flip, the host overlay is cut away from the lifted sheet',
        (tester) async {
      final overlay = _FloodPainter();
      final coverage = await tester.runAsync(
        () => _coverage(_painterAt(0.5, overlay: overlay, size: size), size),
      );

      // The flap is genuinely in the air at mid-flip, so a decoration that
      // flooded the whole viewport must come back MISSING that region —
      // otherwise it is compositing on top of opaque paper and reads as a
      // shadow punched through the sheet.
      expect(
        coverage,
        lessThan(0.9),
        reason: 'host overlay was not clipped by the turning sheet',
      );
      expect(
        coverage,
        greaterThan(0.1),
        reason: 'host overlay must survive on the stationary paper',
      );
    });

    testWidgets('at rest the host overlay covers the whole viewport',
        (tester) async {
      final overlay = _FloodPainter();
      final coverage = await tester.runAsync(
        () => _coverage(_painterAt(0, overlay: overlay, size: size), size),
      );

      // progress 0 = nothing in the air = nothing to occlude. This is the
      // frame the idle (non-drag) layer has to match byte-for-byte, since it
      // draws the same painter with no clip at all.
      expect(coverage, greaterThan(0.99));
    });

    testWidgets('as the sheet lands, the overlay is restored onto it',
        (tester) async {
      final overlay = _FloodPainter();

      // shadowOnset decays back to 0 over the last 14% of progress, so the
      // decoration fades back ONTO the landing sheet instead of popping in
      // when this layer unmounts.
      final plateau = await tester.runAsync(
        () => _coverage(_painterAt(0.5, overlay: overlay, size: size), size),
      );
      final landing = await tester.runAsync(
        () => _coverage(_painterAt(0.995, overlay: overlay, size: size), size),
      );

      expect(
        landing,
        greaterThan(plateau!),
        reason: 'the fold must return to the sheet as it settles flat',
      );
      expect(landing, greaterThan(0.95));
    });

    test('a null overlay leaves every pre-existing host untouched', () {
      expect(PageFlipConfig.defaultSettings.stationaryOverlayPainter, isNull);
    });

    test('copyWith carries and clears the overlay', () {
      final overlay = _FloodPainter();
      final withOverlay = PageFlipConfig.defaultSettings.copyWith(
        stationaryOverlayPainter: overlay,
      );
      expect(withOverlay.stationaryOverlayPainter, same(overlay));
      expect(withOverlay.normalized.stationaryOverlayPainter, same(overlay));
      expect(
        withOverlay
            .copyWith(clearStationaryOverlayPainter: true)
            .stationaryOverlayPainter,
        isNull,
      );
    });

    test('swapping the overlay instance forces a repaint', () {
      final a = _FloodPainter();
      final b = _FloodPainter();
      expect(
        _painterAt(0.5, overlay: b, size: size).shouldRepaint(
          _painterAt(0.5, overlay: a, size: size),
        ),
        isTrue,
      );
    });
  });

  testWidgets('the idle layer mounts the host overlay above page content',
      (tester) async {
    final overlay = _FloodPainter();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageFlipWidget(
            itemCount: 3,
            spreadMode: PageFlipSpreadMode.doubleSpread,
            config: PageFlipConfig.defaultSettings.copyWith(
              stationaryOverlayPainter: overlay,
            ),
            itemBuilder: (context, index) => ColoredBox(
              color: const Color(0xFFEEEEEE),
              child: Center(child: Text('page $index')),
            ),
          ),
        ),
      ),
    );
    // The widget's own layout gate resolves its viewport in a post-frame
    // callback, so the first frame can still be the zero-sized placeholder.
    await tester.pump();
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && identical(w.painter, overlay),
      ),
      findsOneWidget,
      reason: 'the idle layer must mount the host overlay',
    );
    expect(
      overlay.paintCount,
      greaterThan(0),
      reason: 'a settled book must still show its own binding chrome',
    );
  });
}
