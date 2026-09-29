import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

void main() {
  group('horizontal primary axis helpers', () {
    test('purely vertical movement is never reported as horizontal', () {
      expect(horizontalPrimaryDelta(const Offset(0, 5)), isNull);
      expect(horizontalPrimaryVelocity(const Offset(0, 900)), isNull);
    });

    test('purely horizontal movement is reported as dx', () {
      expect(horizontalPrimaryDelta(const Offset(-3, 0)), -3);
      expect(horizontalPrimaryVelocity(const Offset(700, 0)), 700);
    });

    test('diagonal movement defers to delta.dx in the controller', () {
      expect(horizontalPrimaryDelta(const Offset(-3, 2)), isNull);
    });
  });

  group('PageFlipWidget touch steering', () {
    const viewSize = Size(400, 600);

    Widget buildApp({PageFlipConfig config = PageFlipConfig.defaultSettings}) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: viewSize,
                child: PageFlipWidget(
                  itemCount: 3,
                  config: config.copyWith(enableSound: false),
                  itemBuilder: (context, index) => ColoredBox(
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                ),
              ),
            ),
          ),
        );

    PageFlipLayerView layerView(WidgetTester tester) =>
        tester.widget<PageFlipLayerView>(find.byType(PageFlipLayerView));

    testWidgets(
        'vertical-only finger movement re-steers the fold without '
        'changing progress', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // SizedBox spans screen x 200..600. Start at local (300, 300).
      final gesture = await tester.startGesture(const Offset(500, 300));
      await tester.pump();
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();

      final before = layerView(tester);
      expect(before.isDragging, isTrue);
      final progressBefore = before.dragProgress;
      expect(progressBefore, greaterThan(0));

      // Small, purely vertical move: stays below the yield-to-content ratio.
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      final after = layerView(tester);
      expect(
        after.dragProgress,
        progressBefore,
        reason: 'Vertical travel must not count as horizontal flip progress',
      );
      expect(
        after.touchPosition.dy,
        closeTo(before.touchPosition.dy + 40, 0.01),
        reason: 'The flip layer must rebuild with the new touch position',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('changing duration/cutoff config applies to the next flip',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();

      await tester.pumpWidget(
        buildApp(
          config: const PageFlipConfig(
            duration: Duration(milliseconds: 900),
            cutoffForward: 0.9,
          ),
        ),
      );
      await tester.pump();

      final state =
          tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));
      expect(
        state.controller.animationDuration,
        const Duration(milliseconds: 900),
      );
      expect(state.controller.cutoffForward, 0.9);
    });
  });
}
