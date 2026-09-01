import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

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
  required CustomPainter? overlay,
  required Size size,
  bool isDoubleSpread = true,
}) =>
    PageFlipPainter(
      progress: progress,
      isRightToLeft: true,
      touchOffset: Offset(size.width * 0.9, size.height / 2),
      paperBackColor: const Color(0xFFFFFFFF),
      isDoubleSpread: isDoubleSpread,
      stationaryOverlayPainter: overlay,
    );

Future<int> _redAt(
  CustomPainter painter,
  Size size,
  Offset point,
) async {
  final image = await _renderPainter(painter, size);
  final bytes = await image.toByteData();
  image.dispose();
  final x = point.dx.round().clamp(0, size.width.round() - 1);
  final y = point.dy.round().clamp(0, size.height.round() - 1);
  return bytes!.getUint8((y * size.width.round() + x) * 4);
}

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

    testWidgets(
        'a sheet still visibly in the air never gets the whole overlay back',
        (tester) async {
      final overlay = _FloodPainter();

      // Regression: the old restore pass returned EVERY host pixel near the
      // end of a turn. The centre binding may now cross-fade inside its narrow
      // contact band, but unrelated chrome across the rest of the raised sheet
      // must remain occluded (proved at pixel level by the next test).
      final lateFlip = await tester.runAsync(
        () => _coverage(_painterAt(0.9, overlay: overlay, size: size), size),
      );
      final plateau = await tester.runAsync(
        () => _coverage(_painterAt(0.5, overlay: overlay, size: size), size),
      );

      expect(
        lateFlip,
        lessThan(0.9),
        reason: 'the raised sheet received the whole host overlay',
      );
      expect(lateFlip, closeTo(plateau!, 0.35));
    });

    testWidgets(
        'late binding contact restores only the centre band, not all chrome',
        (tester) async {
      final overlay = _FloodPainter();
      const outsideBinding = Offset(100, 150);
      const onBinding = Offset(200, 150);

      final geo = PageFlipGeometry(
        progress: 0.9,
        isRightToLeft: true,
        touchOffset: const Offset(360, 150),
        size: size,
        isDoubleSpread: true,
      );
      final flap = buildFlapScreenClipPath(geo);
      expect(flap.contains(outsideBinding), isTrue);
      expect(flap.contains(onBinding), isTrue);

      final withOverlay = _painterAt(0.9, overlay: overlay, size: size);
      final withoutOverlay = _painterAt(0.9, overlay: null, size: size);
      final values = await tester.runAsync(
        () async => (
          outsideWith: await _redAt(withOverlay, size, outsideBinding),
          outsideWithout: await _redAt(withoutOverlay, size, outsideBinding),
          bindingWith: await _redAt(withOverlay, size, onBinding),
          bindingWithout: await _redAt(withoutOverlay, size, onBinding),
        ),
      );

      expect(
        (values!.outsideWith - values.outsideWithout).abs(),
        lessThanOrEqualTo(1),
        reason: 'centre contact leaked unrelated overlay across the flap',
      );
      expect(
        values.bindingWithout - values.bindingWith,
        greaterThan(8),
        reason: 'the binding itself did not return during contact',
      );
    });

    testWidgets('spine contact never changes single-page overlay occlusion',
        (tester) async {
      final overlay = _FloodPainter();
      const point = Offset(20, 150);
      final withOverlay = _painterAt(
        0.9,
        overlay: overlay,
        size: size,
        isDoubleSpread: false,
      );
      final withoutOverlay = _painterAt(
        0.9,
        overlay: null,
        size: size,
        isDoubleSpread: false,
      );
      final values = await tester.runAsync(
        () async => (
          withOverlay: await _redAt(withOverlay, size, point),
          withoutOverlay: await _redAt(withoutOverlay, size, point),
        ),
      );
      expect(
        (values!.withOverlay - values.withoutOverlay).abs(),
        lessThanOrEqualTo(1),
      );
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
