import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// A centre fold anchored to the binding, like the one a spread host hands the
/// engine through `PageFlipConfig.stationaryOverlayPainter`: one shadow valley
/// whose peak sits ON the spine and falls off to either side.
class _SpineFoldPainter extends CustomPainter {
  const _SpineFoldPainter();

  /// How far the valley reaches onto each leaf. Deliberately WIDER than the
  /// gap the fold line still has to close over the progress range under test,
  /// so the sheet's crease lands inside the decoration rather than clear of it
  /// — which is the whole condition that used to split the fold in two.
  static const double curlWidth = 30;

  /// Peak alpha on the spine itself.
  static const double peak = 0.20;

  @override
  void paint(Canvas canvas, Size size) {
    final spine = size.width / 2;
    for (final side in const <double>[-1, 1]) {
      final outer = spine + side * curlWidth;
      final rect = Rect.fromLTRB(
        math.min(spine, outer),
        0,
        math.max(spine, outer),
        size.height,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: side > 0 ? Alignment.centerLeft : Alignment.centerRight,
            end: side > 0 ? Alignment.centerRight : Alignment.centerLeft,
            colors: <Color>[
              Colors.black.withValues(alpha: peak),
              Colors.black.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpineFoldPainter oldDelegate) => false;
}

void main() {
  const size = Size(800, 500);
  const paper = Color(0xFFF7F1E4);
  const spine = 400.0;
  const fold = _SpineFoldPainter();

  // Sampled well past the fold's own reach on both sides, so the profile is
  // measured out to where the host paints nothing at all.
  const from = 330;
  const to = 470;

  Future<ui.Image> plainSpread() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(Offset.zero & size, Paint()..color = paper);
    return recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
  }

  group('a spread turn never splits the host centre fold in two', () {
    late ui.Image current;
    late ui.Image adjacent;

    setUp(() async {
      current = await plainSpread();
      adjacent = await plainSpread();
    });

    tearDown(() {
      current.dispose();
      adjacent.dispose();
    });

    /// Luminance of the hinge row across [from]..[to], one sample per pixel.
    Future<List<double>> hingeRow(
      WidgetTester tester, {
      required double dragProgress,
      required bool isForward,
      required Offset touchPosition,
      required bool withFold,
    }) async {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: PageFlipLayerView(
                itemCount: 3,
                currentIndex: 1,
                dragProgress: dragProgress,
                isDragging: true,
                isForward: isForward,
                touchPosition: touchPosition,
                pageSnapshots: const {},
                spreadSnapshots: {
                  1: current,
                  if (isForward) 2: adjacent else 0: adjacent,
                },
                pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
                constrainedSize: size,
                isDoubleSpread: true,
                paperFlapColor: paper,
                stationaryOverlayPainter: withFold ? fold : null,
                performanceProfile: DevicePerformanceProfile.high,
                itemBuilder: (context, index) => const ColoredBox(color: paper),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      late List<double> row;
      await tester.runAsync(() async {
        final frame = await boundary.toImage();
        final data = await frame.toByteData();
        final bytes = data!.buffer.asUint8List();
        const y = 250; // the hinge row: the fold pivots about it at every angle
        row = <double>[
          for (var x = from; x <= to; x++)
            () {
              final o = (y * size.width.toInt() + x) * 4;
              return bytes[o] * 0.299 +
                  bytes[o + 1] * 0.587 +
                  bytes[o + 2] * 0.114;
            }(),
        ];
        frame.dispose();
      });
      return row;
    }

    /// How many 8-bit levels the host's fold darkened each column by.
    ///
    /// Differenced against the same frame rendered without the overlay, so the
    /// turning sheet's OWN crease and bend shading — which legitimately darken
    /// the paper right where the answer matters — cancel out and what is left
    /// is the binding decoration alone.
    Future<({List<double> composite, List<double> overlay})> foldProfiles(
      WidgetTester tester, {
      required double dragProgress,
      required bool isForward,
      Offset touchPosition = const Offset(400, 250),
    }) async {
      final withFold = await hingeRow(
        tester,
        dragProgress: dragProgress,
        isForward: isForward,
        touchPosition: touchPosition,
        withFold: true,
      );
      final without = await hingeRow(
        tester,
        dragProgress: dragProgress,
        isForward: isForward,
        touchPosition: touchPosition,
        withFold: false,
      );
      return (
        composite: withFold,
        overlay: <double>[
          for (var i = 0; i < withFold.length; i++) without[i] - withFold[i],
        ],
      );
    }

    /// The deepest rebound anywhere on one flank, in 8-bit levels.
    ///
    /// Walking outward from the fold's darkest column it must only get lighter.
    /// A stretch that darkens again is a SECOND valley — a second fold line.
    double deepestRebound(List<double> flankFromCentre) {
      var shallowest = flankFromCentre.first;
      var worst = 0.0;
      for (final value in flankFromCentre) {
        worst = math.max(worst, value - shallowest);
        shallowest = math.min(shallowest, value);
      }
      return worst;
    }

    /// Deepest second valley while walking away from the composite's floor.
    double deepestCompositeValley(List<double> flankFromFloor) {
      var brightest = flankFromFloor.first;
      var worst = 0.0;
      for (final value in flankFromFloor) {
        worst = math.max(worst, brightest - value);
        brightest = math.max(brightest, value);
      }
      return worst;
    }

    for (final isForward in const <bool>[true, false]) {
      final direction = isForward ? 'forward' : 'backward';
      for (final dragProgress in const <double>[0.90, 0.93, 0.95, 0.97, 0.99]) {
        testWidgets('$direction p=$dragProgress reads as one fold',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final profiles = await foldProfiles(
            tester,
            dragProgress: dragProgress,
            isForward: isForward,
          );
          final profile = profiles.overlay;

          var deepestAt = 0;
          for (var i = 1; i < profile.length; i++) {
            if (profile[i] > profile[deepestAt]) deepestAt = i;
          }

          // The fold belongs ON the binding. Before this was fixed the
          // turning sheet cut the decoration along its own crease, which left
          // the deep part of the valley stranded 14–22px out on the revealed
          // side while the binding itself kept only a ghost — one fold read
          // as two.
          expect(
            (from + deepestAt - spine).abs(),
            lessThanOrEqualTo(4.0),
            reason: 'the fold bottomed out ${from + deepestAt - spine}px off '
                'the spine — it is tracking the sheet, not the binding',
          );

          // A dithered gradient wobbles by a level; a second valley is deeper.
          const wobble = 2.0;
          expect(
            deepestRebound(profile.sublist(deepestAt)),
            lessThan(wobble),
            reason: 'the fold darkens again to the right of its floor — '
                'that second valley is the split fold',
          );
          expect(
            deepestRebound(
              profile.sublist(0, deepestAt + 1).reversed.toList(),
            ),
            lessThan(wobble),
            reason: 'the fold darkens again to the left of its floor — '
                'that second valley is the split fold',
          );

          var compositeDarkestAt = 0;
          for (var i = 1; i < profiles.composite.length; i++) {
            if (profiles.composite[i] <
                profiles.composite[compositeDarkestAt]) {
              compositeDarkestAt = i;
            }
          }
          expect(
            (from + compositeDarkestAt - spine).abs(),
            lessThanOrEqualTo(4.0),
            reason: 'the final composite still bottoms out '
                '${from + compositeDarkestAt - spine}px away from the spine',
          );
          const compositeWobble = 2.0;
          expect(
            deepestCompositeValley(
              profiles.composite.sublist(compositeDarkestAt),
            ),
            lessThan(compositeWobble),
            reason: 'the final composite grows a second valley to the right',
          );
          expect(
            deepestCompositeValley(
              profiles.composite
                  .sublist(0, compositeDarkestAt + 1)
                  .reversed
                  .toList(),
            ),
            lessThan(compositeWobble),
            reason: 'the final composite grows a second valley to the left',
          );
        });
      }
    }

    testWidgets('the contact mask follows a genuinely tilted fold normal',
        (tester) async {
      const maskSize = Size(800, 500);
      final geo = PageFlipGeometry(
        progress: 0.75,
        isRightToLeft: true,
        touchOffset: const Offset(400, 40),
        size: maskSize,
        isDoubleSpread: true,
      );
      expect(geo.angle.abs(), greaterThan(0.01));

      final shader = buildFoldContactMaskShader(
        geo,
        baseOpacity: 0,
        featherWidth: 22,
      );
      expect(shader, isNotNull);

      late Uint8List bytes;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Offset.zero & maskSize,
          Paint()..shader = shader,
        );
        final image = await recorder.endRecording().toImage(
              maskSize.width.toInt(),
              maskSize.height.toInt(),
            );
        final data = await image.toByteData();
        image.dispose();
        bytes = data!.buffer.asUint8List();
      });

      int alphaAt(Offset point) {
        final x = point.dx.round().clamp(0, maskSize.width.toInt() - 1);
        final y = point.dy.round().clamp(0, maskSize.height.toInt() - 1);
        return bytes[(y * maskSize.width.toInt() + x) * 4 + 3];
      }

      final hinge = Offset(geo.foldX, maskSize.height / 2);
      final inward = geo.foldNormal * -1;
      final tangent = Offset(-geo.foldNormal.dy, geo.foldNormal.dx);
      expect(alphaAt(hinge), greaterThan(245));
      expect(alphaAt(hinge + inward * 22), lessThan(12));
      expect(
        alphaAt(hinge + inward * 11 + tangent * 70),
        closeTo(alphaAt(hinge + inward * 11 - tangent * 70), 8),
      );
    });

    testWidgets('the fold deepens monotonically as the sheet lands',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // The engine hands the fold back to the sheet over the last stretch of a
      // turn; if that handover were a step rather than a ramp the binding would
      // blink into existence one frame before this layer unmounts.
      var previous = -1.0;
      for (final dragProgress in const <double>[0.85, 0.9, 0.93, 0.95, 0.99]) {
        final profile = (await foldProfiles(
          tester,
          dragProgress: dragProgress,
          isForward: true,
        ))
            .overlay;
        final depth = profile.reduce(math.max);
        expect(
          depth,
          greaterThanOrEqualTo(previous),
          reason: 'the fold got shallower at p=$dragProgress as the sheet '
              'settled further',
        );
        previous = depth;
      }
    });

    testWidgets('a sheet still in the air keeps the binding off its back',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Mid-flip the crease is half a page from the binding, so nothing the
      // binding casts may reach the sheet — the regression this whole clip
      // exists for ("the fold punches through the paper"). The sheet covers
      // the spine from the moment its free edge sweeps past it, so every
      // sampled column here is sheet.
      final geo = PageFlipGeometry(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: const Offset(400, 250),
        size: size,
        isDoubleSpread: true,
      );
      expect(
        geo.freeEdgeX,
        lessThan(spine - 40),
        reason: 'the sampled band must lie on the sheet for this to mean '
            'anything',
      );

      final profile = (await foldProfiles(
        tester,
        dragProgress: 0.7,
        isForward: true,
      ))
          .overlay;
      final onSheet = profile.sublist(
        0,
        ((geo.foldX - 4).round() - from).clamp(1, profile.length),
      );

      expect(
        onSheet.reduce(math.max),
        lessThan(1.0),
        reason: 'the binding valley showed through the lifted sheet',
      );
    });
  });
}
