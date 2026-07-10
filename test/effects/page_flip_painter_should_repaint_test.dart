import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

void main() {
  group('PageFlipPainter.shouldRepaint', () {
    final base = PageFlipPainter(
      progress: 0.5,
      isRightToLeft: true,
      touchOffset: Offset.zero,
      paperBackColor: Colors.white,
    );

    test('identical fields returns false', () {
      final identical_ = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(base.shouldRepaint(identical_), isFalse);
    });

    test('progress change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.6,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('isRightToLeft change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: false,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('touchOffset change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(0, 100),
        paperBackColor: Colors.white,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('paperBackColor change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.black,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('thinPaperStrength change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        thinPaperStrength: 0.5,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('endRevealStrength change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        endRevealStrength: 0.5,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('isDoubleSpread change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        isDoubleSpread: true,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('isForward change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        isForward: false,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('paperOpacity change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        paperOpacity: 0.5,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapContentFadeOutEnd change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapContentFadeOutEnd: 0.3,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapContentRevealStart change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapContentRevealStart: 0.7,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapContentRevealEnd change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapContentRevealEnd: 0.9,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapFrontImage change returns true', () async {
      final img = await createTestImage();
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontImage: img,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 150),
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapFrontSrcRect change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapFrontSrcRect: const Rect.fromLTWH(0, 0, 100, 150),
      );
      expect(base.shouldRepaint(diff), isTrue);
    });

    test('flapFrontSettleImage change returns true from settle source', () {
      final withSettle = PageFlipPainter(
        progress: 0.9,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final withNonNullSettle = PageFlipPainter(
        progress: 0.9,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(withSettle.shouldRepaint(withNonNullSettle), isFalse);
    });

    test('legacy no-op double-spread controls do not repaint', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        flapBackStrength: 0.5,
        doubleSpreadMidFoldBleed: 0.75,
      );
      expect(base.shouldRepaint(diff), isFalse);
    });

    test('performanceProfile change returns true', () {
      final diff = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
        performanceProfile: DevicePerformanceProfile.low,
      );
      expect(base.shouldRepaint(diff), isTrue);
    });
  });
}

/// Helper: create a 1x1 test image.
Future<ui.Image> createTestImage() {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = Colors.white,
  );
  return recorder.endRecording().toImage(1, 1);
}
