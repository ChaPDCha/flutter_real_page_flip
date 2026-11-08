import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_painter.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

// Render only the moving sheet, using an already-ready image. Ink detected
// here cannot come from a stationary page or asynchronous application content.
void main() {
  const size = Size(400, 600);
  const samples = [0.10, 0.25, 0.50, 0.75, 0.84, 0.90];

  for (final profile in DevicePerformanceProfile.values) {
    for (final dark in [false, true]) {
      for (final forward in [true, false]) {
        for (final settleReveal in [true, false]) {
          testWidgets(
            '${profile.name}, dark=$dark, forward=$forward, reveal=$settleReveal: '
            'printed text remains on the sheet through intermediate frames',
            (tester) async {
              await tester.runAsync(() async {
                final paper =
                    dark ? const Color(0xff1a1a1a) : const Color(0xfff7f1e3);
                final ink =
                    dark ? const Color(0xff20e0e0) : const Color(0xffc81030);
                final sourceRecorder = ui.PictureRecorder();
                final sourceCanvas = Canvas(sourceRecorder);
                sourceCanvas.drawRect(
                  Offset.zero & size,
                  Paint()..color = paper,
                );
                final text = TextPainter(
                  text: TextSpan(
                    text: 'VISIBLE TEXT 0123456789',
                    style: TextStyle(fontSize: 22, color: ink),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout(maxWidth: size.width);
                for (var y = 8.0; y < size.height - 24; y += 32) {
                  text.paint(sourceCanvas, Offset(0, y));
                }
                text.dispose();
                final sourcePicture = sourceRecorder.endRecording();
                final source = await sourcePicture.toImage(400, 600);
                sourcePicture.dispose();
                try {
                  for (final progress in samples) {
                    final recorder = ui.PictureRecorder();
                    final canvas = Canvas(recorder);
                    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
                    PageFlipPainter(
                      progress: forward ? progress : 1 - progress,
                      isRightToLeft: true,
                      isActualForward: forward,
                      touchOffset: const Offset(200, 300),
                      paperBackColor: paper,
                      performanceProfile: profile,
                      enableSinglePageSettleReveal: settleReveal,
                      flapFrontImage: source,
                      flapFrontSrcRect: Offset.zero & size,
                      flapFrontSettleImage: source,
                      flapFrontSettleSrcRect: Offset.zero & size,
                    ).paint(canvas, size);
                    final picture = recorder.endRecording();
                    final image = await picture.toImage(400, 600);
                    picture.dispose();
                    final pixels =
                        (await image.toByteData())!.buffer.asUint8List();
                    var inkPixels = 0;
                    for (var i = 0; i < pixels.length; i += 4) {
                      final contrast = dark
                          ? pixels[i + 1] - pixels[i]
                          : pixels[i] - pixels[i + 1];
                      if (contrast > 25) inkPixels++;
                    }
                    image.dispose();
                    expect(
                      inkPixels,
                      greaterThan(100),
                      reason: '${profile.name}, dark=$dark, '
                          'forward=$forward, progress=$progress: '
                          'ready text must remain on the moving sheet',
                    );
                  }
                } finally {
                  source.dispose();
                }
              });
            },
          );
        }
      }
    }
  }
}
