import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

void main() {
  for (final isDoubleSpread in const <bool>[false, true]) {
    for (final size in const <Size>[
      Size(400, 600),
      Size(800, 600),
      Size(2200, 700),
      Size(360, 1600),
    ]) {
      for (final isForward in const <bool>[true, false]) {
        for (final profile in DevicePerformanceProfile.values) {
          for (final paper in const <Color>[Colors.white, Color(0xFF171717)]) {
            final isDark = paper.computeLuminance() < 0.2;
            testWidgets(
              'crease stays attached at $size spread=$isDoubleSpread forward=$isForward '
              '$profile dark=$isDark',
              (tester) async {
                for (final touchFraction in const <double>[0, 0.5, 1]) {
                  final g = PageFlipGeometry(
                    progress: 0.5,
                    isRightToLeft: true,
                    touchOffset:
                        Offset(size.width / 2, size.height * touchFraction),
                    size: size,
                    isDoubleSpread: isDoubleSpread,
                    isForward: isForward,
                  );
                  final recorder = ui.PictureRecorder();
                  final canvas = Canvas(recorder);
                  canvas.drawRect(Offset.zero & size, Paint()..color = paper);
                  PageFlipPainter(
                    progress: 0.5,
                    isRightToLeft: true,
                    touchOffset: g.touchOffset,
                    paperBackColor: paper,
                    isDoubleSpread: isDoubleSpread,
                    isForward: isForward,
                    performanceProfile: profile,
                    geo: g,
                  ).paint(canvas, size);
                  final picture = recorder.endRecording();
                  late Uint8List bytes;
                  await tester.runAsync(() async {
                    ui.Image? frame;
                    try {
                      frame = await picture.toImage(
                        size.width.toInt(),
                        size.height.toInt(),
                      );
                      bytes = (await frame.toByteData())!.buffer.asUint8List();
                    } finally {
                      picture.dispose();
                      frame?.dispose();
                    }
                  });

                  for (final rowFraction in const <double>[0.1, 0.5, 0.9]) {
                    final localY = size.height * rowFraction;
                    final hinge = MatrixUtils.transformPoint(
                      g.transform,
                      Offset(foldCurveXAt(g, localY), localY),
                    );
                    final samples = <double>[];
                    for (var distance = -32; distance <= 32; distance++) {
                      final point = hinge + g.foldNormal * distance.toDouble();
                      final x = point.dx.floor();
                      final y = point.dy.floor();
                      final offset = (y * size.width.toInt() + x) * 4;
                      samples.add(
                        bytes[offset] * 0.299 +
                            bytes[offset + 1] * 0.587 +
                            bytes[offset + 2] * 0.114,
                      );
                    }
                    final context = 'touch=$touchFraction row=$rowFraction';
                    if (!isDark) {
                      final darkest = samples.reduce((a, b) => a < b ? a : b);
                      final darkestAtHinge = samples
                          .sublist(30, 35)
                          .reduce((a, b) => a < b ? a : b);
                      // A broad valley may dither by 1–2 levels. Its near-hinge
                      // pixels must still be as dark as the rest of the crease.
                      expect(
                        darkestAtHinge,
                        lessThanOrEqualTo(darkest + 2),
                        reason: 'A separate darker band formed beside the '
                            'physical paper hinge ($context, samples=$samples).',
                      );
                    }
                    var largestJump = 0.0;
                    for (var i = 29; i <= 36; i++) {
                      final jump = (samples[i] - samples[i - 1]).abs();
                      if (jump > largestJump) largestJump = jump;
                    }
                    // Uniform faces of the same sheet need continuous shading
                    // at their hinge. A hard luminance step reads as a cut edge.
                    expect(
                      largestJump,
                      lessThanOrEqualTo(12),
                      reason: 'A $largestJump-level hard luminance edge split '
                          'the two plain faces ($context, samples=$samples).',
                    );
                  }
                }
              },
            );
          }
        }
      }
    }
  }
}
