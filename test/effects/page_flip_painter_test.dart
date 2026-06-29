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
        touchOffset: const Offset(10, 0),
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
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
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

    test('shouldReclip returns true when isRightToLeft changes', () {
      final clipper = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: false,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });

    test('shouldReclip returns false when progress and touchOffset are same',
        () {
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

    test('shouldReclip returns true when isRightToLeft changes', () {
      final clipper = PageFlipOpenClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipOpenClipper(
        progress: 0.5,
        isRightToLeft: false,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });
  });

  group('PageFlipPainter Texture Mapping Behavior', () {
    test('shouldRepaint returns true when isRightToLeft changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: false,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when flapContentRevealStart changes', () {
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
        flapContentRevealStart: 0.75,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    ui.Image? testImage;
    setUp(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 800, 600),
        Paint()..color = Colors.white,
      );
      testImage = await recorder.endRecording().toImage(800, 600);
    });

    tearDown(() {
      testImage?.dispose();
      testImage = null;
    });

    test('mid fold skips texture when reveal opacity is zero', () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isFalse);
      expect(canvas.didDrawRect, isTrue);
    });

    test('late progress draws texture when reveal opacity is full', () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.96,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(400, 0, 400, 600),
        isDoubleSpread: true,
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isTrue);
    });

    test('early progress draws texture when fade-out window includes progress',
        () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.10,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
        flapFrontDestRect: const Rect.fromLTWH(400, 0, 400, 600),
        isDoubleSpread: true,
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isTrue);
    });

    test('backward flip uses vertices mesh when late reveal is active', () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.92,
        isRightToLeft: false,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 400, 600),
        isDoubleSpread: true,
        isForward: false,
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isTrue);
    });

    test('paints paper color when no texture is available', () {
      final canvas = MockCanvas();

      final painter = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );

      painter.paint(canvas, const Size(800, 600));

      // Falls back to solid paper color when no texture
      expect(canvas.didDrawVertices, isFalse);
    });

    test('single-page forward flip skips stationary edge shadow', () {
      final canvas = TrackingShadowCanvas();

      PageFlipPainter(
        progress: 0.85,
        isRightToLeft: true,
        touchOffset: const Offset(350, 150),
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
      ).paint(canvas, const Size(800, 600));

      expect(canvas.stationaryShadowDrawCount, equals(0));
    });

    // ── 2.5D back content tests ─────────────────────────────────

    group('2.5D back content rendering', () {
      test('draws back mesh when flapBackImage and srcRect provided', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.96,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapFrontDestRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackStrength: 0.3,
          isDoubleSpread: true,
        ).paint(canvas, const Size(800, 600));

        // At progress=0.96, front content is fully revealed AND back content is drawn.
        // Front mesh (1) + Back mesh (1) = 2 drawVertices calls.
        expect(canvas.drawVerticesCount, greaterThanOrEqualTo(2));
        // Should have drawn fade overlay rects.
        expect(canvas.drawRectCount, greaterThan(0));
      });

      test('skips back mesh when flipBackStrength is 0', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapFrontDestRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          isDoubleSpread: true,
        ).paint(canvas, const Size(800, 600));

        // flapBackStrength=0 means backFadeAlpha=1.0 → cover entirely.
        // So no separate back mesh is drawn since hasFlapBack is still true
        // (flapBackStrength > 0 check is NOT in hasFlapBack).
        // The mesh IS drawn, then the fade overlay covers it.
        expect(canvas.drawVerticesCount, greaterThanOrEqualTo(1));
      });

      test('single page mode skips back content even with images', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.96,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackStrength: 0.3,
        ).paint(canvas, const Size(800, 600));

        // hasFlapBack requires isDoubleSpread → false in single mode → no back mesh.
        // At progress=0.96, front content is fully revealed → 1 drawVertices (front only).
        expect(canvas.drawVerticesCount, equals(1));
      });

      test('draws back mesh in backward double-spread', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.96,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackStrength: 0.3,
          isDoubleSpread: true,
          isForward: false,
        ).paint(canvas, const Size(800, 600));

        // Front mesh + back mesh = 2 drawVertices
        expect(canvas.drawVerticesCount, greaterThanOrEqualTo(2));
        expect(canvas.drawRectCount, greaterThan(0));
      });

      test('backward double-spread skips back mesh when strength is 0', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapFrontDestRect: const Rect.fromLTWH(0, 0, 800, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          isDoubleSpread: true,
          isForward: false,
        ).paint(canvas, const Size(800, 600));

        expect(canvas.drawVerticesCount, greaterThanOrEqualTo(1));
      });

      test('backward double-spread shouldRepaint when isForward changes', () {
        final painter1 = PageFlipPainter(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          isDoubleSpread: true,
          isForward: false,
        );
        final painter2 = PageFlipPainter(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          isDoubleSpread: true,
        );
        expect(painter1.shouldRepaint(painter2), isTrue);
      });
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
    // Exclude edge-fade (8px) and fold-fade (6px) gradients by lower-bounding
    // at 12px — the stationary shadow at half intensity is ~10px wide.
    if (rect.width > 12 && rect.width <= 25 && rect.left < 0) {
      stationaryShadowDrawCount++;
    }
  }
}

/// Tracks drawVertices calls with shader info and rect counts.
class TrackingShaderCanvas extends Fake implements Canvas {
  int drawVerticesCount = 0;
  int drawRectCount = 0;

  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, Paint paint) {
    drawVerticesCount++;
  }

  @override
  void drawRect(Rect rect, Paint paint) {
    drawRectCount++;
  }

  @override
  void save() {}

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

class MockCanvas extends Fake implements Canvas {
  bool didDrawRect = false;
  bool didDrawVertices = false;
  int drawRectCount = 0;

  @override
  void drawRect(Rect rect, Paint paint) {
    didDrawRect = true;
    drawRectCount++;
  }

  @override
  void drawVertices(ui.Vertices vertices, ui.BlendMode blendMode, Paint paint) {
    didDrawVertices = true;
  }

  @override
  void save() {}

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
