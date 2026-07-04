import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

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

  group('PageFlipEngine Constants', () {
    test('flapHighlightPeakBase returns expected strengthened values', () {
      expect(flapHighlightPeakBase(isPaperDark: false), equals(0.10));
      expect(flapHighlightPeakBase(isPaperDark: true), equals(0.07));
    });

    test('flapHighlightMidBase returns expected strengthened values', () {
      expect(flapHighlightMidBase(isPaperDark: false), equals(0.06));
      expect(flapHighlightMidBase(isPaperDark: true), equals(0.04));
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

    test('double-spread mid fold skips texture when reveal opacity is zero',
        () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        isDoubleSpread: true,
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isFalse);
      expect(canvas.didDrawRect, isTrue);
    });

    test('single-page medium mid fold keeps the back-facing flap blank', () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
      ).paint(canvas, const Size(800, 600));

      // Medium is the default lightweight profile: the back-facing flap should
      // be blank paper through the main fold, not a textured page back.
      expect(canvas.didDrawVertices, isFalse);
      expect(canvas.didDrawRect, isTrue);
    });

    test('single-page high mid fold may draw the curling page texture', () {
      final canvas = MockCanvas();

      PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: testImage,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
        performanceProfile: DevicePerformanceProfile.high,
      ).paint(canvas, const Size(800, 600));

      expect(canvas.didDrawVertices, isTrue);
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
        isDoubleSpread: true,
        performanceProfile: DevicePerformanceProfile.high,
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
        isDoubleSpread: true,
        isForward: false,
        performanceProfile: DevicePerformanceProfile.high,
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
      ).paint(canvas, const Size(800, 600));

      expect(canvas.stationaryShadowDrawCount, equals(0));
    });

    // ── 2.5D back content tests ─────────────────────────────────

    group('2.5D back content rendering', () {
      test('high draws back mesh when flapBackImage and srcRect provided', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.96,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackStrength: 0.3,
          isDoubleSpread: true,
          performanceProfile: DevicePerformanceProfile.high,
        ).paint(canvas, const Size(800, 600));

        // At progress=0.96, front content is fully revealed AND back content is drawn.
        // Front mesh (1) + Back mesh (1) = 2 drawVertices calls.
        expect(canvas.drawVerticesCount, greaterThanOrEqualTo(2));
        // Should have drawn fade overlay rects.
        expect(canvas.drawRectCount, greaterThan(0));
      });

      test('medium skips back mesh even when flapBackStrength is enabled', () {
        final canvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.96,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackStrength: 0.3,
          isDoubleSpread: true,
        ).paint(canvas, const Size(800, 600));

        // Medium may draw the late-settle front texture, but never the 2.5D
        // opposite-page back mesh.
        expect(canvas.drawVerticesCount, equals(1));
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
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          isDoubleSpread: true,
        ).paint(canvas, const Size(800, 600));

        // flapBackStrength=0 is a real performance-off switch: no hidden
        // back mesh should be built and then covered by paper.
        expect(canvas.drawVerticesCount, equals(0));
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
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          flapBackStrength: 0.3,
          isDoubleSpread: true,
          isForward: false,
          performanceProfile: DevicePerformanceProfile.high,
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
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(400, 0, 400, 600),
          isDoubleSpread: true,
          isForward: false,
        ).paint(canvas, const Size(800, 600));

        expect(canvas.drawVerticesCount, equals(0));
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

    group('skipEarlyMesh performance gating (double-spread)', () {
      const earlyFadeProgress = 0.10;
      const settleProgress = 0.90;
      const midFoldProgress = 0.50;
      const canvasSize = Size(800, 600);
      const frontSrc = Rect.fromLTWH(400, 0, 400, 600);

      void paintWithProfile({
        required TrackingShaderCanvas canvas,
        required double progress,
        required DevicePerformanceProfile profile,
        bool isForward = true,
        double flapBackStrength = 0.0,
      }) {
        PageFlipPainter(
          progress: progress,
          isRightToLeft: isForward,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: frontSrc,
          flapBackImage: testImage,
          flapBackSrcRect: const Rect.fromLTWH(0, 0, 400, 600),
          flapBackStrength: flapBackStrength,
          isDoubleSpread: true,
          isForward: isForward,
          performanceProfile: profile,
        ).paint(canvas, canvasSize);
      }

      test('early fade: low/medium skip front mesh, high draws mesh', () {
        final lowCanvas = TrackingShaderCanvas();
        final mediumCanvas = TrackingShaderCanvas();
        final highCanvas = TrackingShaderCanvas();

        paintWithProfile(
          canvas: lowCanvas,
          progress: earlyFadeProgress,
          profile: DevicePerformanceProfile.low,
        );
        paintWithProfile(
          canvas: mediumCanvas,
          progress: earlyFadeProgress,
          profile: DevicePerformanceProfile.medium,
        );
        paintWithProfile(
          canvas: highCanvas,
          progress: earlyFadeProgress,
          profile: DevicePerformanceProfile.high,
        );

        expect(
          flapFrontContentRevealOpacity(
            earlyFadeProgress,
            isDoubleSpread: true,
          ),
          greaterThan(0.001),
          reason: 'early fade window must have visible content reveal',
        );
        expect(lowCanvas.drawVerticesCount, equals(0));
        expect(mediumCanvas.drawVerticesCount, equals(0));
        expect(highCanvas.drawVerticesCount, greaterThan(0));
      });

      test('settle phase: medium profile draws front mesh', () {
        final canvas = TrackingShaderCanvas();

        paintWithProfile(
          canvas: canvas,
          progress: settleProgress,
          profile: DevicePerformanceProfile.medium,
        );

        expect(
          isFlapSettlePhase(settleProgress, isForward: true),
          isTrue,
        );
        expect(canvas.drawVerticesCount, greaterThan(0));
      });

      test('mid-fold hides mesh via zero content reveal (all profiles)', () {
        for (final profile in DevicePerformanceProfile.values) {
          final canvas = TrackingShaderCanvas();
          paintWithProfile(
            canvas: canvas,
            progress: midFoldProgress,
            profile: profile,
          );

          expect(
            flapFrontContentRevealOpacity(
              midFoldProgress,
              isDoubleSpread: true,
            ),
            closeTo(0, 0.001),
          );
          expect(
            canvas.drawVerticesCount,
            equals(0),
            reason: 'profile=$profile',
          );
        }
      });

      test('backward early gesture maps to settle phase on medium', () {
        final canvas = TrackingShaderCanvas();

        paintWithProfile(
          canvas: canvas,
          progress: earlyFadeProgress,
          profile: DevicePerformanceProfile.medium,
          isForward: false,
        );

        expect(
          normalizedFlapProgress(earlyFadeProgress, isForward: false),
          closeTo(0.90, 0.001),
        );
        expect(
          isFlapSettlePhase(earlyFadeProgress, isForward: false),
          isTrue,
        );
        expect(canvas.drawVerticesCount, greaterThan(0));
      });

      test('backward mid-fold skips mesh on medium', () {
        final canvas = TrackingShaderCanvas();

        paintWithProfile(
          canvas: canvas,
          progress: midFoldProgress,
          profile: DevicePerformanceProfile.medium,
          isForward: false,
        );

        expect(
          normalizedFlapProgress(midFoldProgress, isForward: false),
          closeTo(0.50, 0.001),
        );
        expect(
          isFlapSettlePhase(midFoldProgress, isForward: false),
          isFalse,
        );
        expect(canvas.drawVerticesCount, equals(0));
      });


      test('custom revealStart gates skipEarlyMesh on medium profile', () {
        const customRevealStart = 0.75;
        final earlyCanvas = TrackingShaderCanvas();
        final settleCanvas = TrackingShaderCanvas();

        PageFlipPainter(
          progress: 0.10,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: frontSrc,
          isDoubleSpread: true,
          flapContentRevealStart: customRevealStart,
        ).paint(earlyCanvas, canvasSize);

        PageFlipPainter(
          progress: 0.80,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: frontSrc,
          isDoubleSpread: true,
          flapContentRevealStart: customRevealStart,
        ).paint(settleCanvas, canvasSize);

        expect(
          isFlapSettlePhase(
            0.10,
            isForward: true,
            revealStart: customRevealStart,
          ),
          isFalse,
        );
        expect(
          isFlapSettlePhase(
            0.80,
            isForward: true,
            revealStart: customRevealStart,
          ),
          isTrue,
        );
        expect(earlyCanvas.drawVerticesCount, equals(0));
        expect(settleCanvas.drawVerticesCount, greaterThan(0));
      });

      test('narrow flap skips mesh even when content reveal is active', () {
        const narrowProgress = 0.005;
        final geo = PageFlipGeometry(
          progress: narrowProgress,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          size: canvasSize,
          isDoubleSpread: true,
        );
        expect(geo.flapVisibleWidth, lessThan(8.0));

        final canvas = TrackingShaderCanvas();
        PageFlipPainter(
          progress: narrowProgress,
          isRightToLeft: true,
          touchOffset: Offset.zero,
          paperBackColor: Colors.white,
          flapFrontImage: testImage,
          flapFrontSrcRect: frontSrc,
          isDoubleSpread: true,
          geo: geo,
          performanceProfile: DevicePerformanceProfile.high,
        ).paint(canvas, canvasSize);

        expect(
          flapFrontContentRevealOpacity(
            narrowProgress,
            isDoubleSpread: true,
          ),
          greaterThan(0.001),
        );
        expect(canvas.drawVerticesCount, equals(0));
      });
    });

    group('settle-phase texture selection', () {
      late ui.Image dualToneImage;
      const canvasSize = Size(800, 600);

      setUp(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 100, 100),
          Paint()..color = const Color(0xFFFF0000),
        );
        canvas.drawRect(
          const Rect.fromLTWH(100, 0, 100, 100),
          Paint()..color = const Color(0xFF00FF00),
        );
        dualToneImage = await recorder.endRecording().toImage(200, 100);
      });

      tearDown(() => dualToneImage.dispose());

      Future<({int redPixels, int greenPixels})> scanTexturePixels(
        PageFlipPainter painter,
      ) async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), canvasSize);
        final image = await recorder.endRecording().toImage(
              canvasSize.width.toInt(),
              canvasSize.height.toInt(),
            );
        final byteData = await image.toByteData();
        expect(byteData, isNotNull);

        var redPixels = 0;
        var greenPixels = 0;
        for (var i = 0; i < byteData!.lengthInBytes; i += 4) {
          final r = byteData.getUint8(i);
          final g = byteData.getUint8(i + 1);
          final b = byteData.getUint8(i + 2);
          if (r > 240 && g > 240 && b > 240) continue;
          if (r > 180 && r > g + 80 && r > b + 80) redPixels++;
          if (g > 180 && g > r + 80 && g > b + 80) greenPixels++;
        }
        image.dispose();
        return (redPixels: redPixels, greenPixels: greenPixels);
      }

      test('settle phase renders settle snapshot color in flap mesh', () async {
        final pixels = await scanTexturePixels(
          PageFlipPainter(
            progress: 0.92,
            isRightToLeft: true,
            touchOffset: Offset.zero,
            paperBackColor: Colors.white,
            flapFrontImage: dualToneImage,
            flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
            flapFrontSettleImage: dualToneImage,
            flapFrontSettleSrcRect: const Rect.fromLTWH(100, 0, 100, 100),
            isDoubleSpread: true,
            performanceProfile: DevicePerformanceProfile.high,
          ),
        );

        expect(pixels.greenPixels, greaterThan(0));
        expect(pixels.greenPixels, greaterThan(pixels.redPixels));
      });

      test('pre-settle phase renders flapFront snapshot color in flap mesh',
          () async {
        final pixels = await scanTexturePixels(
          PageFlipPainter(
            progress: 0.10,
            isRightToLeft: true,
            touchOffset: Offset.zero,
            paperBackColor: Colors.white,
            flapFrontImage: dualToneImage,
            flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
            flapFrontSettleImage: dualToneImage,
            flapFrontSettleSrcRect: const Rect.fromLTWH(100, 0, 100, 100),
            isDoubleSpread: true,
            performanceProfile: DevicePerformanceProfile.high,
          ),
        );

        expect(pixels.redPixels, greaterThan(0));
        expect(pixels.redPixels, greaterThan(pixels.greenPixels));
      });

      test('settle phase falls back to flapFront snapshot when settle missing',
          () async {
        final pixels = await scanTexturePixels(
          PageFlipPainter(
            progress: 0.92,
            isRightToLeft: true,
            touchOffset: Offset.zero,
            paperBackColor: Colors.white,
            flapFrontImage: dualToneImage,
            flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 100),
            isDoubleSpread: true,
            performanceProfile: DevicePerformanceProfile.high,
          ),
        );

        expect(pixels.redPixels, greaterThan(0));
        expect(pixels.redPixels, greaterThan(pixels.greenPixels));
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
  void drawPath(Path path, Paint paint) {}

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
  void drawPath(Path path, Paint paint) {}

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
