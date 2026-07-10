import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  const size = Size(400, 300);
  const background = Color(0xFFFF00FF);
  const currentLeft = Color(0xFFCC2222);
  const currentRight = Color(0xFF2255CC);
  const nextLeft = Color(0xFF22CC55);
  const nextRight = Color(0xFFF0C020);
  const previousLeft = Color(0xFF22CACC);
  const previousRight = Color(0xFF9A33CC);

  Future<ui.Image> spread(Color left, Color right) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 300),
      Paint()..color = left,
    );
    canvas.drawRect(
      const Rect.fromLTWH(200, 0, 200, 300),
      Paint()..color = right,
    );
    return recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
  }

  Widget liveSpread(int index) {
    final colors = switch (index) {
      0 => (previousLeft, previousRight),
      1 => (currentLeft, currentRight),
      _ => (nextLeft, nextRight),
    };
    return Row(
      children: [
        Expanded(child: ColoredBox(color: colors.$1)),
        Expanded(child: ColoredBox(color: colors.$2)),
      ],
    );
  }

  group('double-spread verso repagination pixels', () {
    late ui.Image previous;
    late ui.Image current;
    late ui.Image next;

    setUp(() async {
      previous = await spread(previousLeft, previousRight);
      current = await spread(currentLeft, currentRight);
      next = await spread(nextLeft, nextRight);
    });

    tearDown(() {
      previous.dispose();
      current.dispose();
      next.dispose();
    });

    Future<_Pixels> render(
      WidgetTester tester, {
      required int currentIndex,
      required double dragProgress,
      required bool isDragging,
      required bool isForward,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      final boundaryKey = GlobalKey();
      final content = isDragging
          ? PageFlipLayerView(
              itemCount: 3,
              currentIndex: currentIndex,
              dragProgress: dragProgress,
              isDragging: true,
              isForward: isForward,
              touchPosition: const Offset(200, 150),
              pageSnapshots: const {},
              spreadSnapshots: {0: previous, 1: current, 2: next},
              pageKeys: {for (var i = 0; i < 3; i++) i: GlobalKey()},
              constrainedSize: size,
              isDoubleSpread: true,
              paperFlapColor: const Color(0xFFF8F2E8),
              performanceProfile: DevicePerformanceProfile.high,
              itemBuilder: (context, index) => liveSpread(index),
            )
          : SizedBox.fromSize(
              size: size,
              child: liveSpread(currentIndex),
            );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: background),
          home: Scaffold(
            backgroundColor: background,
            body: RepaintBoundary(
              key: boundaryKey,
              child: content,
            ),
          ),
        ),
      );
      await tester.pump();

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      late _Pixels pixels;
      await tester.runAsync(() async {
        final frame = await boundary.toImage();
        final data = await frame.toByteData();
        pixels = _Pixels(
          List<int>.of(data!.buffer.asUint8List()),
          size.width.toInt(),
        );
        frame.dispose();
      });
      return pixels;
    }

    for (final isForward in <bool>[true, false]) {
      final direction = isForward ? 'forward' : 'backward';
      for (final dragProgress in <double>[0.3, 0.6, 0.9]) {
        testWidgets('$direction p=$dragProgress has no hole and maps verso',
            (tester) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pixels = await render(
            tester,
            currentIndex: 1,
            dragProgress: dragProgress,
            isDragging: true,
            isForward: isForward,
          );

          expect(
            pixels.countNear(background, tolerance: 12),
            equals(0),
            reason: 'Any magenta pixel is an uncovered compositing hole.',
          );
          expect(
            pixels.transparentPixelCount,
            equals(0),
            reason: 'Every viewport pixel must be covered by opaque paper.',
          );

          final floatProgress = isForward ? dragProgress : 1 - dragProgress;
          final geo = PageFlipGeometry(
            progress: floatProgress,
            isRightToLeft: true,
            touchOffset: const Offset(200, 150),
            size: size,
            isDoubleSpread: true,
            isForward: isForward,
          );
          final flapX = ((geo.foldX + geo.freeEdgeX) / 2).round();
          final revealX = isForward
              ? (geo.foldX + (size.width - geo.foldX) * 0.75).round()
              : (geo.foldX * 0.25).round();

          expect(
            pixels.at(flapX, size.height ~/ 2),
            _nearColor(isForward ? nextLeft : previousRight, 75),
            reason: '$direction flap must show the adjacent spread verso.',
          );
          expect(
            pixels.at(revealX, size.height ~/ 2),
            _nearColor(isForward ? nextRight : previousLeft, 45),
            reason: '$direction revealed region must show destination content.',
          );
        });
      }
    }

    testWidgets('forward p=0.97 is continuous with settled next spread',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nearSettle = await render(
        tester,
        currentIndex: 1,
        dragProgress: 0.97,
        isDragging: true,
        isForward: true,
      );
      late _Pixels settled;
      await tester.runAsync(() async {
        final data = await next.toByteData();
        settled = _Pixels(
          List<int>.of(data!.buffer.asUint8List()),
          size.width.toInt(),
        );
      });

      expect(
        settled.at(100, 150),
        _nearColor(nextLeft, 5),
        reason: 'Settled left-page control pixel must be the next spread.',
      );
      expect(
        nearSettle.at(100, 150),
        _nearColor(nextLeft, 75),
        reason: 'Near-settle flap must already carry next-left verso pixels.',
      );

      expect(
        nearSettle.meanAbsoluteDifference(settled),
        lessThan(18),
        reason:
            'Verso strip should land on the same destination pixels without '
            'a settle content swap pop.',
      );
    });
  });
}

Matcher _nearColor(Color expected, int tolerance) => predicate<Color>(
      (actual) =>
          (actual.r * 255 - expected.r * 255).abs() <= tolerance &&
          (actual.g * 255 - expected.g * 255).abs() <= tolerance &&
          (actual.b * 255 - expected.b * 255).abs() <= tolerance,
      'within $tolerance RGB levels of $expected',
    );

class _Pixels {
  const _Pixels(this.bytes, this.width);

  final List<int> bytes;
  final int width;

  Color at(int x, int y) {
    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes[offset + 3],
      bytes[offset],
      bytes[offset + 1],
      bytes[offset + 2],
    );
  }

  int countNear(Color color, {required int tolerance}) {
    var count = 0;
    for (var offset = 0; offset < bytes.length; offset += 4) {
      if ((bytes[offset] - color.r * 255).abs() <= tolerance &&
          (bytes[offset + 1] - color.g * 255).abs() <= tolerance &&
          (bytes[offset + 2] - color.b * 255).abs() <= tolerance) {
        count++;
      }
    }
    return count;
  }

  double meanAbsoluteDifference(_Pixels other) {
    var difference = 0;
    for (var offset = 0; offset < bytes.length; offset += 4) {
      difference += (bytes[offset] - other.bytes[offset]).abs();
      difference += (bytes[offset + 1] - other.bytes[offset + 1]).abs();
      difference += (bytes[offset + 2] - other.bytes[offset + 2]).abs();
    }
    return difference / (bytes.length ~/ 4) / 3;
  }

  int get transparentPixelCount {
    var count = 0;
    for (var offset = 3; offset < bytes.length; offset += 4) {
      if (bytes[offset] < 255) count++;
    }
    return count;
  }
}
