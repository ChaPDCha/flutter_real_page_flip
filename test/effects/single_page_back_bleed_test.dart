import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

/// Records solid (non-shader) drawRect paints so tests can detect the
/// thin-paper "back content dim" overlay that masks the peeled page content
/// down to a faint bleed-through in single-page mode.
class _SolidRectTrackingCanvas extends Fake implements Canvas {
  final List<({Color color, double alpha})> solidRects = [];

  @override
  void drawRect(Rect rect, Paint paint) {
    if (paint.shader == null) {
      solidRects.add((color: paint.color, alpha: paint.color.a));
    }
  }

  @override
  void drawVertices(
    ui.Vertices vertices,
    ui.BlendMode blendMode,
    Paint paint,
  ) {}

  @override
  void save() {}

  @override
  void saveLayer(Rect? bounds, Paint paint) {}

  @override
  void restore() {}

  @override
  void transform(Float64List matrix4) {}

  @override
  void clipRect(
    Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}

  @override
  void clipPath(
    Path path, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {}
}

bool _isFaintPaperOverlay(({Color color, double alpha}) r) {
  // Paper-white, partially transparent (not the full-opacity paper underlay,
  // not a near-transparent edge fade): this is the bleed-through dim overlay.
  final isPaperWhite = r.color.r > 0.9 && r.color.g > 0.9 && r.color.b > 0.9;
  return isPaperWhite && r.alpha > 0.2 && r.alpha < 0.9;
}

void main() {
  late ui.Image testImage;

  setUp(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 800, 600),
      Paint()..color = Colors.white,
    );
    testImage = await recorder.endRecording().toImage(800, 600);
  });

  tearDown(() => testImage.dispose());

  group('single-page back bleed-through (thin Bible paper)', () {
    test(
        'default (opacity 1.0) keeps peeled content crisp — no faint paper '
        'overlay', () {
      final canvas = _SolidRectTrackingCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
        performanceProfile: DevicePerformanceProfile.high,
      ).paint(canvas, const Size(800, 600));

      expect(
        canvas.solidRects.where(_isFaintPaperOverlay),
        isEmpty,
        reason: 'with full opacity the single-page peel must not dim its own '
            'content; current behaviour is preserved.',
      );
    });

    test(
        'singlePageBackContentOpacity < 1 dims the peeled content to a faint '
        'bleed-through during the peel', () {
      final canvas = _SolidRectTrackingCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
        singlePageBackContentOpacity: 0.35,
        performanceProfile: DevicePerformanceProfile.high,
      ).paint(canvas, const Size(800, 600));

      final overlays = canvas.solidRects.where(_isFaintPaperOverlay).toList();
      expect(
        overlays,
        isNotEmpty,
        reason: 'a faint paper overlay must dim the peeled back content so it '
            'reads like thin Bible paper bleed-through.',
      );
      // Content visible at ~35% => overlay paper alpha ~65%.
      expect(
        overlays.any((r) => (r.alpha - 0.65).abs() < 0.12),
        isTrue,
        reason: 'overlay strength should leave ~35% content showing through. '
            'alphas=${overlays.map((r) => r.alpha).toList()}',
      );
    });

    test(
        'bleed overlay does NOT snap off at the settle boundary '
        '(left-edge flicker regression)', () {
      // The flicker: the bleed overlay was gated on a hard isSettlePhase
      // boolean, so its alpha dropped from ~0.65 to ~0 in a single frame at
      // the settle start (~0.85) near the end of the swipe. Sample the overlay
      // strength just below and just above the boundary; it must change
      // gradually, not snap.
      double overlayAlphaAt(double progress) {
        final canvas = _SolidRectTrackingCanvas();
        PageFlipPainter(
          progress: progress,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
          // Settle content present so useSettle flips true past revealStart —
          // the exact condition that used to kill the overlay abruptly.
          flapFrontSettleImage: testImage,
          flapFrontSettleSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
          flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
          singlePageBackContentOpacity: 0.35,
          performanceProfile: DevicePerformanceProfile.high,
        ).paint(canvas, const Size(800, 600));
        final overlays = canvas.solidRects.where(_isFaintPaperOverlay).toList();
        return overlays.isEmpty
            ? 0.0
            : overlays.map((r) => r.alpha).reduce((a, b) => a > b ? a : b);
      }

      final below = overlayAlphaAt(0.84); // peel, just before settle
      final above = overlayAlphaAt(0.86); // just into settle
      expect(
        (below - above).abs(),
        lessThan(0.15),
        reason: 'overlay must relax smoothly across the settle boundary '
            '(below=$below, above=$above) — a large drop is the flicker.',
      );
      expect(
        below,
        greaterThan(0.4),
        reason: 'peel side should still carry the bleed dim',
      );
    });

    test('shouldRepaint returns true when singlePageBackContentOpacity changes',
        () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        singlePageBackContentOpacity: 0.35,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });
}
