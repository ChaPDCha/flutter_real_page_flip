import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

void main() {
  group('PageFlipGestureLayer', () {
    late PageFlipStateController controller;

    setUp(() {
      controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (_) {},
        onEffectTrigger: (_, {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('double-spread half-width swipe completes flip',
        (tester) async {
      controller.updateCachedWidth(200);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 3,
            ),
          ),
        ),
      );

      await tester.dragFrom(
        const Offset(350, 300),
        const Offset(-190, 0),
      );
      await tester.pumpAndSettle();

      expect(controller.currentIndex, 1);
      expect(controller.dragProgress, 0);
    });

    testWidgets('horizontal drag on layer advances flip controller',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Center(child: SelectableText('Selectable body')),
                PageFlipGestureLayer(
                  controller: controller,
                  sensitivity: 0.5,
                  totalPages: 3,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.dragFrom(
        const Offset(200, 300),
        const Offset(-180, 0),
      );
      await tester.pumpAndSettle();

      expect(controller.currentIndex, 1);
    });

    testWidgets('blocks content pointers while horizontal drag is active',
        (tester) async {
      var tapOnText = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => tapOnText++,
                  child: const Center(child: SelectableText('Selectable body')),
                ),
                PageFlipGestureLayer(
                  controller: controller,
                  sensitivity: 0.5,
                  totalPages: 3,
                ),
              ],
            ),
          ),
        ),
      );

      final center = const Offset(200, 300);
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();

      expect(controller.blocksContentPointers, isTrue);

      await gesture.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(controller.blocksContentPointers, isFalse);
      expect(tapOnText, 0);
      expect(controller.currentIndex, 1);
    });

    testWidgets('diagonal pointer deltas do not assert', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 3,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(350, 300));
      await gesture.moveBy(const Offset(-30, -8));
      await gesture.moveBy(const Offset(-120, -4));
      await gesture.up();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(controller.currentIndex, 1);
    });
  });
}
