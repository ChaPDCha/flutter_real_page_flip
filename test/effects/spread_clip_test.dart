import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  const viewport = Size(400, 300);

  Future<ui.Image> solidSpreadImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 300),
      Paint()..color = const Color(0xFFE53935),
    );
    return recorder.endRecording().toImage(400, 300);
  }

  group('clipFullSpreadHalf', () {
    testWidgets('does not expand snapshot to double width', (tester) async {
      final image = await solidSpreadImage();
      addTearDown(image.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: viewport,
              child: clipFullSpreadHalf(
                alignment: Alignment.centerRight,
                child: buildViewportSnapshotImage(
                  image,
                  viewportSize: viewport,
                ),
              ),
            ),
          ),
        ),
      );

      final snapshotBox = tester.getSize(find.byType(RawImage));
      expect(snapshotBox.width, viewport.width);
      expect(snapshotBox.height, viewport.height);
      expect(find.byType(FractionallySizedBox), findsNothing);
    });

    testWidgets('right half align clips to viewport half width', (tester) async {
      final image = await solidSpreadImage();
      addTearDown(image.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: viewport,
              child: clipFullSpreadHalf(
                alignment: Alignment.centerRight,
                child: buildViewportSnapshotImage(
                  image,
                  viewportSize: viewport,
                ),
              ),
            ),
          ),
        ),
      );

      final align = tester.widget<Align>(
        find.byWidgetPredicate(
          (w) => w is Align && w.widthFactor == 0.5,
        ),
      );
      expect(align.alignment, Alignment.centerRight);
    });
  });

  group('clipSpreadPageHalf', () {
    testWidgets('expands half-width slot child for host layouts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                Expanded(
                  child: clipSpreadPageHalf(
                    alignment: Alignment.centerLeft,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FractionallySizedBox), findsOneWidget);
    });
  });

  group('buildViewportSnapshotImage', () {
    testWidgets('wraps snapshot in viewport SizedBox', (tester) async {
      final image = await solidSpreadImage();
      addTearDown(image.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: buildViewportSnapshotImage(
              image,
              viewportSize: viewport,
            ),
          ),
        ),
      );

      final box = tester.widget<SizedBox>(
        find.ancestor(
          of: find.byType(RawImage),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, viewport.width);
      expect(box.height, viewport.height);
    });
  });
}
