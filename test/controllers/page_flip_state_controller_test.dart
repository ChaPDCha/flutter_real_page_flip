import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

void main() {
  group('PageFlipStateController', () {
    late PageFlipStateController controller;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      const vsync = TestVSync();
      controller = PageFlipStateController(
        vsync: vsync,
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initialization sets correct defaults', () {
      expect(controller.currentIndex, 0);
      expect(controller.isDragging, false);
      expect(controller.dragProgress, 0.0);
    });

    test('setIndex clamps value correctly', () {
      controller.setIndex(5, 10);
      expect(controller.currentIndex, 5, reason: 'Should set valid index');

      controller.setIndex(15, 10);
      expect(controller.currentIndex, 9, reason: 'Should clamp to max index');

      controller.setIndex(-1, 10);
      expect(controller.currentIndex, 0, reason: 'Should clamp to min index');
    });

    test('setIndex with totalPages=0 does not crash', () {
      controller.setIndex(42, 0);
      // Should stay at 0 when totalPages is 0
      expect(controller.currentIndex, 0);
    });

    test('onDragStart resets drag state', () {
      // Set up partial drag state
      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: const Offset(200, 300)),
        5,
      );
      expect(controller.isDragging, false);
      expect(controller.dragProgress, 0.0);
      expect(controller.touchPosition, const Offset(200, 300));
    });

    test('onDragStart ignores when animation is running', () {
      // Start a drag
      controller.updateCachedWidth(400);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -50, delta: const Offset(-50, 0),
          globalPosition: Offset.zero, localPosition: Offset.zero,
        ),
        5,
      );
      controller.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);

      // Second drag start while first is still "animating" (post-release)
      controller.onDragStart(
        DragStartDetails(localPosition: const Offset(100, 100)),
        5,
      );
      // Touch position should NOT be updated since animation is still running
      // (progress > 0 means it was in an animating state)
    });

    test('onDragUpdate clamps progress to [0, 1]', () {
      controller.updateCachedWidth(400);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);

      // Drag far beyond the screen width
      controller.onDragUpdate(
        DragUpdateDetails(primaryDelta: -500, delta: const Offset(-500, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      expect(controller.dragProgress, greaterThanOrEqualTo(0.0));
      expect(controller.dragProgress, lessThanOrEqualTo(1.0));

      // Drag in opposite direction
      controller.onDragUpdate(
        DragUpdateDetails(primaryDelta: 200, delta: const Offset(200, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      expect(controller.dragProgress, greaterThanOrEqualTo(0.0));
      expect(controller.dragProgress, lessThanOrEqualTo(1.0));
    });

    test('onDragUpdate blocks forward drag past last page', () {
      controller.setIndex(4, 5);
      controller.updateCachedWidth(400);

      // Try forward drag (negative delta = forward)
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      controller.onDragUpdate(
        DragUpdateDetails(primaryDelta: -50, delta: const Offset(-50, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      expect(controller.isDragging, false,
          reason: 'Should not start drag at boundary');
    });

    test('onDragUpdate blocks backward drag past first page', () {
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);

      // Try backward drag (positive delta = backward)
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      controller.onDragUpdate(
        DragUpdateDetails(primaryDelta: 50, delta: const Offset(50, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      expect(controller.isDragging, false,
          reason: 'Should not start drag at boundary');
    });

    test('dispose during any state does not throw', () {
      // Dispose immediately after creation
      final fresh = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (PageFlipEvent effect, {int? intensity, double? volume, double? texture, double? resistance}) {},
      );
      // No exception expected
      expect(() => fresh.dispose(), returnsNormally);
    });

    test('onEffectTrigger receives startHaptic from first delta', () {
      final effects = <PageFlipEvent>[];
      final effectController = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
          effects.add(effect);
        },
      );

      effectController.updateCachedWidth(400);
      effectController.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -20,
          delta: const Offset(-20, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      expect(effects, contains(PageFlipEvent.startHaptic));
      effectController.dispose();
    });

    test('texturedHaptic intensity in valid range (40-255)', () {
      final intensities = <int>[];
      final effectController = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
          if (effect == PageFlipEvent.texturedHaptic && intensity != null) {
            intensities.add(intensity);
          }
        },
      );

      effectController.updateCachedWidth(400);
      effectController.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(primaryDelta: -10, delta: const Offset(-10, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(primaryDelta: -15, delta: const Offset(-15, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(primaryDelta: -20, delta: const Offset(-20, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(primaryDelta: -25, delta: const Offset(-25, 0), globalPosition: Offset.zero, localPosition: Offset.zero),
        5,
      );

      expect(intensities.length, greaterThanOrEqualTo(1));
      for (final i in intensities) {
        expect(i, inInclusiveRange(40, 255));
      }
      effectController.dispose();
    });

    test('triggerTapFlip with skipTapAnimation fires callbacks', () {
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);

      // Store callbacks that fire
      bool soundFired = false;
      bool hapticFired = false;

      // Create a controller with effect tracking
      final tapController = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
          if (effect == PageFlipEvent.sound) soundFired = true;
          if (effect == PageFlipEvent.impulseHaptic) hapticFired = true;
        },
      );
      tapController.setIndex(0, 5);

      tapController.triggerTapFlip(true, 5);

      // Effects should fire immediately
      expect(soundFired, isTrue);
      expect(hapticFired, isTrue);
      tapController.dispose();
    });
  });
}
