import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipPainter', () {
    test('shouldRepaint returns true when progress changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
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
      );
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when touchOffset changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset(10, 0),
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when paperBackColor changes', () {
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
        paperBackColor: Colors.black,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when paperOpacity changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        paperOpacity: 1.0,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        paperOpacity: 0.5,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when flapFrontImage changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: null,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: null,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 1, 1),
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when flapFrontDestRect changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 400, 600),
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontDestRect: const Rect.fromLTWH(400, 0, 400, 600),
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when flapFrontSrcRect changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontSrcRect: const Rect.fromLTWH(100, 0, 100, 100),
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });

  group('PageFlipClipper', () {
    test('shouldReclip returns true when progress changes', () {
      final clipper = PageFlipClipper(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipClipper(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });

    test('shouldReclip returns false when progress and touchOffset are same', () {
      final clipper = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isFalse);
    });
  });

  group('PageFlipOpenClipper', () {
    test('shouldReclip returns true when progress changes', () {
      final clipper = PageFlipOpenClipper(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipOpenClipper(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });
  });

  group('PageFlipPainter Texture Mapping Behavior', () {
    test('forward flip uses drawImageRect when texture is available', () {
      final canvas = MockCanvas();
      final mockImage = MockImage();

      final painter = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: mockImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 100, 100),
      );

      painter.paint(canvas, const Size(800, 600));

      // Fix: forward flip now shows texture when available (eliminates "blank paper" feel)
      expect(canvas.didDrawImageRect, isTrue);
    });

    test('backward flip uses drawImageRect when texture is available', () {
      final canvas = MockCanvas();
      final mockImage = MockImage();

      final painter = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: false,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: mockImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 100, 100),
      );

      painter.paint(canvas, const Size(800, 600));

      expect(canvas.didDrawImageRect, isTrue);
    });

    test('paints paper color when no texture is available', () {
      final canvas = MockCanvas();

      final painter = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: null,
        flapFrontSrcRect: null,
        flapFrontDestRect: null,
      );

      painter.paint(canvas, const Size(800, 600));

      // Falls back to solid paper color when no texture
      expect(canvas.didDrawImageRect, isFalse);
    });

    test('single-page forward flip skips stationary edge shadow', () {
      final canvas = TrackingShadowCanvas();

      PageFlipPainter(
        progress: 0.85,
        isRightToLeft: true,
        touchOffset: const Offset(350, 150),
        paperBackColor: Colors.white,
        isDoubleSpread: false,
        isForward: true,
        flapFrontImage: MockImage(),
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
      ).paint(canvas, const Size(800, 600));

      expect(canvas.stationaryShadowDrawCount, equals(0));
    });
  });
}

/// Tracks stationary-edge shadow draws (narrow rect left of the flap body).
class TrackingShadowCanvas extends MockCanvas {
  int stationaryShadowDrawCount = 0;

  @override
  void drawRect(Rect rect, Paint paint) {
    super.drawRect(rect, paint);
    // Stationary shadow sits just left of the fold: foldX - flapWidth - ~20px.
    if (rect.width <= 25 && rect.left < 0) {
      stationaryShadowDrawCount++;
    }
  }
}

class MockImage extends Fake implements ui.Image {
  @override
  int get width => 100;
  @override
  int get height => 100;
}

class MockCanvas extends Fake implements Canvas {
  bool didDrawImageRect = false;
  bool didDrawRect = false;

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) {
    didDrawImageRect = true;
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    didDrawRect = true;
  }

  @override
  void save() {}

  @override
  void restore() {}

  @override
  void transform(Float64List matrix4) {}

  @override
  void clipRect(Rect rect, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {}

  @override
  void clipPath(Path path, {ui.ClipOp clipOp = ui.ClipOp.intersect, bool doAntiAlias = true}) {}
}
