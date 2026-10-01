import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Input-space robustness for the pure rendering pipeline.
///
/// Viewports are not always phone-shaped: split screens, foldables, desktop
/// windows being dragged, and collapsing layouts all hand the engine tiny,
/// huge, or extreme-aspect sizes mid-turn, and raw pointer coordinates leave
/// the widget. None of that may produce a non-finite coordinate: `Canvas`
/// asserts on NaN rects, offsets, and matrices, and in release builds a NaN
/// silently draws garbage. These tests sweep the input space instead of
/// checking a few hand-picked points.
void main() {
  const sizes = <Size>[
    Size.zero,
    Size(0, 600),
    Size(400, 0),
    Size(1, 1),
    Size(8, 8),
    Size(17, 900),
    Size(900, 17),
    Size(390, 844),
    Size(844, 390),
    Size(1366, 1024),
    Size(2732, 2048),
    Size(8000, 120),
  ];

  const touchValues = <double>[
    double.nan,
    double.infinity,
    double.negativeInfinity,
    -1000000000,
    -50,
    0,
    0.5,
    300,
    1000000000,
  ];

  const edgeProgress = <double>[0, 1e-6, 1 - 1e-6, 1, 1e-4, 1 - 1e-4];

  bool finite(Offset o) => o.dx.isFinite && o.dy.isFinite;

  bool inside(Offset o, Size s) =>
      o.dx >= 0 && o.dx <= s.width && o.dy >= 0 && o.dy <= s.height;

  group('PageFlipGeometry over the whole input space', () {
    test('every derived value is finite and within its contract', () {
      final random = math.Random(7);
      var cases = 0;
      for (final size in sizes) {
        for (final spread in <bool>[false, true]) {
          for (final forward in <bool>[false, true]) {
            for (var i = 0; i < 40; i++) {
              var progress = random.nextDouble() * 1.4 - 0.2;
              if (i < edgeProgress.length) progress = edgeProgress[i];
              final touch = Offset(
                touchValues[random.nextInt(touchValues.length)],
                touchValues[random.nextInt(touchValues.length)],
              );
              final g = PageFlipGeometry(
                progress: progress,
                isRightToLeft: true,
                touchOffset: touch,
                size: size,
                isDoubleSpread: spread,
                isForward: forward,
              );
              cases++;
              final where = 'size=$size spread=$spread forward=$forward '
                  'progress=$progress touch=$touch';

              for (final value in <double>[
                g.foldX,
                g.spineX,
                g.angle,
                g.shadowIntensity,
                g.flapVisibleWidth,
                g.flapLeft,
                g.freeEdgeX,
                g.curvatureAmount,
                g.curveOffset,
              ]) {
                expect(value.isFinite, isTrue, reason: where);
              }
              for (final point in <Offset>[
                g.foldNormal,
                g.foldLineTop,
                g.foldLineBottom,
                g.flapEdgeTop,
                g.flapEdgeBottom,
                g.foldCurveControl,
                g.flapCurveControl,
              ]) {
                expect(finite(point), isTrue, reason: where);
              }
              expect(g.transform.storage.every((v) => v.isFinite), isTrue);
              expect(g.foldNormal.distance, closeTo(1, 1e-6), reason: where);
              expect(g.angle.abs(), lessThanOrEqualTo(kMaxFoldAngle + 1e-12));
              expect(g.shadowIntensity, inInclusiveRange(0.0, 1.0));
              expect(g.flapVisibleWidth, greaterThanOrEqualTo(0));
              expect(g.progress, inInclusiveRange(0.0, 1.0));
            }
          }
        }
      }
      expect(cases, sizes.length * 2 * 2 * 40);
    });

    test('a non-finite touch steers like a centred finger (level fold)', () {
      for (final dy in <double>[
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final g = PageFlipGeometry(
          progress: 0.5,
          isRightToLeft: true,
          touchOffset: Offset(200, dy),
          size: const Size(400, 800),
        );
        expect(g.angle, 0, reason: 'dy=$dy');
      }
    });

    test('touch below and above the page tilt in opposite directions', () {
      PageFlipGeometry at(double dy) => PageFlipGeometry(
            progress: 0.5,
            isRightToLeft: true,
            touchOffset: Offset(200, dy),
            size: const Size(400, 800),
          );
      expect(at(0).angle.sign, -at(800).angle.sign);
      expect(at(400).angle, closeTo(0, 1e-12));
    });
  });

  group('clampFlipTouchPosition', () {
    test('always lands inside the viewport and is finite', () {
      final random = math.Random(3);
      for (final size in sizes) {
        for (var i = 0; i < 60; i++) {
          var scale = 1.0;
          if (random.nextBool()) scale = random.nextDouble();
          final x = touchValues[random.nextInt(touchValues.length)] * scale;
          final y = touchValues[random.nextInt(touchValues.length)];
          final raw = Offset(x, y);
          final clamped = clampFlipTouchPosition(raw, size);
          final where = 'raw=$raw size=$size';
          expect(finite(clamped), isTrue, reason: where);
          expect(clamped.dx, inInclusiveRange(0, size.width), reason: where);
          expect(clamped.dy, inInclusiveRange(0, size.height), reason: where);
          if (finite(raw) && inside(raw, size)) {
            expect(clamped, raw, reason: 'in-range input must pass through');
          }
        }
      }
    });
  });

  group('PageFlipPainter over the whole input space', () {
    late ui.Image snapshot;

    setUpAll(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 64, 96),
        Paint()..color = const Color(0xFF3366CC),
      );
      final picture = recorder.endRecording();
      snapshot = await picture.toImage(64, 96);
      picture.dispose();
    });

    tearDownAll(() => snapshot.dispose());

    test('never throws or asserts on any viewport, progress, or touch', () {
      final random = math.Random(11);
      const paintSizes = <Size>[
        Size(8, 8),
        Size(17, 900),
        Size(900, 17),
        Size(390, 844),
        Size(844, 390),
        Size(1366, 1024),
        Size(2732, 2048),
      ];
      const papers = <Color>[
        Color(0xFFFFFFFF),
        Color(0xFFF4ECD8),
        Color(0xFF121212),
        Color(0x80FFFFFF),
      ];
      PageFlipPainter? previous;

      for (var i = 0; i < 600; i++) {
        final size = paintSizes[random.nextInt(paintSizes.length)];
        final spread = random.nextBool();
        final forward = random.nextBool();
        final renderForward = !spread || forward;
        var progress = random.nextDouble();
        if (i % 10 == 0) progress = edgeProgress[i ~/ 10 % edgeProgress.length];
        final touch = clampFlipTouchPosition(
          Offset(
            touchValues[random.nextInt(touchValues.length)],
            touchValues[random.nextInt(touchValues.length)],
          ),
          size,
        );
        final geo = PageFlipGeometry(
          progress: progress,
          isRightToLeft: true,
          touchOffset: touch,
          size: size,
          isDoubleSpread: spread,
          isForward: renderForward,
        );
        final withImage = random.nextDouble() < 0.7;
        final imageSize = Size(
          snapshot.width.toDouble(),
          snapshot.height.toDouble(),
        );
        Rect? srcRect;
        Rect? settleRect;
        if (withImage) {
          srcRect = flapFrontSourceRect(
            imageSize: imageSize,
            isDoubleSpread: spread,
            isForward: renderForward,
            floatProgress: progress,
          );
          settleRect = flapFrontSettleSourceRect(
            imageSize: imageSize,
            isDoubleSpread: spread,
            isForward: renderForward,
            floatProgress: progress,
          );
        }
        final config = PageFlipConfig(
          thinPaperStrength: random.nextDouble(),
          endRevealStrength: random.nextDouble(),
          paperOpacity: random.nextDouble(),
          singlePageBackContentOpacity: random.nextDouble(),
          flapContentFadeOutEnd: random.nextDouble(),
          flapContentRevealStart: random.nextDouble(),
          flapContentRevealEnd: random.nextDouble(),
        ).normalized;
        final profile = DevicePerformanceProfile.values[random.nextInt(3)];
        final overlay = random.nextBool() ? const _GutterOverlay() : null;

        final painter = PageFlipPainter(
          progress: progress,
          isRightToLeft: true,
          touchOffset: touch,
          paperBackColor: papers[random.nextInt(papers.length)],
          isDoubleSpread: spread,
          isForward: renderForward,
          isActualForward: forward,
          devicePixelRatio: const <double>[1, 2, 3.5][random.nextInt(3)],
          paperOpacity: config.paperOpacity,
          thinPaperStrength: config.thinPaperStrength,
          endRevealStrength: config.endRevealStrength,
          flapContentFadeOutEnd: config.flapContentFadeOutEnd,
          flapContentRevealStart: config.flapContentRevealStart,
          flapContentRevealEnd: config.flapContentRevealEnd,
          flapFrontImage: withImage ? snapshot : null,
          flapFrontSrcRect: srcRect,
          flapFrontSettleImage: withImage ? snapshot : null,
          flapFrontSettleSrcRect: settleRect,
          singlePageBackContentOpacity: config.singlePageBackContentOpacity,
          enableSinglePageSettleReveal: random.nextBool(),
          geo: random.nextBool() ? geo : null,
          performanceProfile: profile,
          stationaryOverlayPainter: overlay,
          stationaryOverlayOwnsCenterGutter: random.nextBool(),
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        expect(
          () => painter.paint(canvas, size),
          returnsNormally,
          reason: 'case $i: size=$size spread=$spread forward=$forward '
              'progress=$progress touch=$touch',
        );
        recorder.endRecording().dispose();

        final last = previous;
        if (last != null) {
          expect(() => painter.shouldRepaint(last), returnsNormally);
        }
        previous = painter;
      }
    });
  });

  group('PageFlipGestureArbitration properties', () {
    final random = math.Random(5);
    final samples = <({double dx, double dy, double s})>[
      for (var i = 0; i < 4000; i++)
        (
          dx: (random.nextDouble() * 2 - 1) * 120,
          dy: (random.nextDouble() * 2 - 1) * 120,
          s: random.nextDouble(),
        ),
    ];

    bool accepts(double dx, double dy, double s) =>
        PageFlipGestureArbitration.shouldAcceptFlipDrag(
          totalDx: dx,
          totalDy: dy,
          sensitivity: s,
        );

    bool yields(double dx, double dy, double s) =>
        PageFlipGestureArbitration.shouldYieldToContent(
          totalDx: dx,
          totalDy: dy,
          sensitivity: s,
        );

    test('flip and content never both claim the same movement', () {
      for (final p in samples) {
        expect(accepts(p.dx, p.dy, p.s) && yields(p.dx, p.dy, p.s), isFalse);
      }
    });

    test('decisions ignore direction (mirror symmetric)', () {
      for (final p in samples) {
        final a = accepts(p.dx, p.dy, p.s);
        expect(accepts(-p.dx, p.dy, p.s), a);
        expect(accepts(p.dx, -p.dy, p.s), a);
        expect(yields(-p.dx, -p.dy, p.s), yields(p.dx, p.dy, p.s));
      }
    });

    test('more horizontal travel never revokes flip intent', () {
      for (final p in samples) {
        if (!accepts(p.dx, p.dy, p.s)) continue;
        for (final k in <double>[1.1, 1.5, 3, 10]) {
          expect(accepts(p.dx * k, p.dy, p.s), isTrue, reason: '$p x$k');
        }
      }
    });

    test('higher sensitivity never makes a flip harder to start', () {
      for (final p in samples) {
        if (!accepts(p.dx, p.dy, p.s)) continue;
        final higher = p.s + (1 - p.s) * random.nextDouble();
        expect(accepts(p.dx, p.dy, higher), isTrue, reason: '$p -> $higher');
      }
    });

    test('slop stays in a sane pixel range for any sensitivity', () {
      for (final s in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final slop = PageFlipGestureArbitration.checkSlopForSensitivity(s);
        expect(slop, inInclusiveRange(1.0, 18.0));
        expect(accepts(0, slop * 3, s), isFalse, reason: 'vertical at $s');
        expect(accepts(slop + 0.5, 0, s), isTrue, reason: 'horizontal at $s');
        expect(accepts(slop - 0.5, 0, s), isFalse, reason: 'inside slop $s');
      }
    });
  });

  group('PageFlipConfig.normalized over hostile input', () {
    const hostile = <double>[
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1000000000000,
      -1,
      // ignore: prefer_int_literals
      -0.0,
      0,
      0.3,
      1,
      1.5,
      1000000000000,
    ];

    test('every numeric field lands finite and in range, idempotently', () {
      final random = math.Random(13);
      double pick() => hostile[random.nextInt(hostile.length)];

      for (var i = 0; i < 1500; i++) {
        final raw = PageFlipConfig(
          duration: Duration(
            microseconds: (random.nextDouble() * 4e7 - 1e7).round(),
          ),
          cutoffForward: pick(),
          cutoffPrevious: pick(),
          sensitivity: pick(),
          edgeTapWidthRatio: pick(),
          paperOpacity: pick(),
          thinPaperStrength: pick(),
          endRevealStrength: pick(),
          flapContentFadeOutEnd: pick(),
          flapContentRevealStart: pick(),
          flapContentRevealEnd: pick(),
          flapBackStrength: pick(),
          doubleSpreadMidFoldBleed: pick(),
          singlePageBackContentOpacity: pick(),
          maxSnapshotPixelRatio: random.nextBool() ? null : pick(),
        );
        final n = raw.normalized;
        final where = 'case $i';

        for (final unit in <double>[
          n.cutoffForward,
          n.cutoffPrevious,
          n.sensitivity,
          n.paperOpacity,
          n.thinPaperStrength,
          n.endRevealStrength,
          n.flapContentFadeOutEnd,
          n.flapContentRevealStart,
          n.flapContentRevealEnd,
          n.flapBackStrength,
          n.doubleSpreadMidFoldBleed,
          n.singlePageBackContentOpacity,
        ]) {
          expect(unit.isFinite, isTrue, reason: where);
          expect(unit, inInclusiveRange(0.0, 1.0), reason: where);
        }
        expect(n.edgeTapWidthRatio, inInclusiveRange(0.0, 0.5));
        expect(n.duration, greaterThan(Duration.zero), reason: where);
        expect(n.duration, lessThanOrEqualTo(const Duration(seconds: 10)));
        final ratio = n.maxSnapshotPixelRatio;
        if (ratio != null) expect(ratio, inInclusiveRange(0.25, 4.0));

        // Phase math relies on fadeOutEnd <= revealStart <= revealEnd.
        expect(
          n.flapContentFadeOutEnd,
          lessThanOrEqualTo(n.flapContentRevealStart),
          reason: where,
        );
        expect(
          n.flapContentRevealStart,
          lessThanOrEqualTo(n.flapContentRevealEnd),
          reason: where,
        );

        // Normalising a normalised config is the identity (no reallocation,
        // no drift), and equal configs hash equally.
        expect(identical(n.normalized, n), isTrue, reason: where);
        expect(n.copyWith() == n, isTrue, reason: where);
        expect(n.copyWith().hashCode, n.hashCode, reason: where);
      }
    });
  });
}

/// Minimal host overlay: a binding gutter band and a fore-edge line.
class _GutterOverlay extends CustomPainter {
  const _GutterOverlay();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x22000000);
    final gutter = Rect.fromLTWH(size.width / 2 - 6, 0, 12, size.height);
    final foreEdge = Rect.fromLTWH(size.width - 2, 0, 2, size.height);
    canvas.drawRect(gutter, paint);
    canvas.drawRect(foreEdge, paint);
  }

  @override
  bool shouldRepaint(covariant _GutterOverlay oldDelegate) => false;
}
