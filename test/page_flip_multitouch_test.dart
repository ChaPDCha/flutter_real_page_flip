import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/widgets/page_flip_gesture_layer.dart';

void main() {
  group('PageFlipGestureLayer multi-touch', () {
    late PageFlipStateController controller;

    setUp(() {
      controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 100),
        onUpdate: () {},
        onPageFinalized: (_) {},
        onEffectTrigger: (_,
            {intensity,
            pageIndex,
            resistance,
            texture,
            timestampMs,
            volume,}) {},
      );
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('second pointer down is ignored during active drag',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      // Start first pointer drag
      final gesture1 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 1,
      );
      await gesture1.moveBy(const Offset(-200, 0));

      // Second pointer down should be ignored
      final gesture2 = await tester.startGesture(
        const Offset(200, 200),
        pointer: 2,
      );
      await gesture2.moveBy(const Offset(-100, 0));

      await gesture1.up();
      await tester.pumpAndSettle();

      // Controller should have completed flip from first pointer
      expect(controller.currentIndex, equals(1));
    });

    testWidgets('second pointer is ignored after first is active',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      final gesture1 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 1,
      );

      // Second pointer down – should be silently ignored
      final gesture2 = await tester.startGesture(
        const Offset(200, 200),
        pointer: 2,
      );
      await gesture2.moveBy(const Offset(-100, 0));
      await gesture2.up();

      // First pointer still active, should continue
      await gesture1.moveBy(const Offset(-200, 0));
      await gesture1.up();
      await tester.pumpAndSettle();

      expect(controller.currentIndex, equals(1));
    });

    testWidgets('after first pointer up, new pointer can start flip',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      // First pointer: small drag that does not reach flip threshold
      final gesture1 = await tester.startGesture(
        const Offset(200, 300),
        pointer: 1,
      );
      await gesture1.moveBy(const Offset(-5, 0));
      await gesture1.up();
      // Let any snap-back animation complete
      await tester.pumpAndSettle();

      // Second pointer: full flip drag
      final gesture2 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 2,
      );
      await gesture2.moveBy(const Offset(-200, 0));
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controller.currentIndex, equals(1));
    });

    testWidgets('first pointer cancel allows subsequent pointer',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      // First pointer: cancel mid-drag
      final gesture1 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 1,
      );
      await gesture1.moveBy(const Offset(-200, 0));
      await gesture1.cancel();

      // Second pointer should be able to start fresh
      final gesture2 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 2,
      );
      await gesture2.moveBy(const Offset(-200, 0));
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(controller.currentIndex, equals(1));
    });

    testWidgets('three rapid pointer changes maintain consistency',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      // 1. Start pointer 1, small move
      final gesture1 = await tester.startGesture(
        const Offset(350, 300),
        pointer: 1,
      );
      await gesture1.moveBy(const Offset(-50, 0));

      // 2. Pointer 2 down (ignored)
      final gesture2 = await tester.startGesture(
        const Offset(100, 300),
        pointer: 2,
      );
      await gesture2.up();

      // 3. Continue pointer 1
      await gesture1.moveBy(const Offset(-150, 0));
      await gesture1.up();
      await tester.pumpAndSettle();

      expect(controller.currentIndex, equals(1));
    });

    testWidgets('single pointer down and up without drag is harmless',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: PageFlipGestureLayer(
              controller: controller,
              sensitivity: 0.5,
              totalPages: 5,
            ),
          ),
        ),
      );

      // Tap down and up without movement
      final gesture = await tester.startGesture(const Offset(200, 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.currentIndex, equals(0));
      expect(controller.isDragging, isFalse);
    });
  });
}
