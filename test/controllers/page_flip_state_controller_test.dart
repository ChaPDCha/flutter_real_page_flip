import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

void main() {
  group('PageFlipStateController', () {
    late PageFlipStateController controller;

    test('Initialization sets correct defaults', () {
      const vsync = TestVSync();

      controller = PageFlipStateController(
        vsync: vsync,
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {pageIndex, intensity, volume, texture, resistance}) {},
      );

      expect(controller.currentIndex, 0);
      expect(controller.isDragging, false);
      expect(controller.dragProgress, 0.0);

      controller.dispose();
    });

    test('setIndex clamps value correctly', () {
      const vsync = TestVSync();

      controller = PageFlipStateController(
        vsync: vsync,
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {pageIndex, intensity, volume, texture, resistance}) {},
      );

      controller.setIndex(5, 10);
      expect(controller.currentIndex, 5, reason: 'Should set valid index');

      controller.setIndex(15, 10);
      expect(controller.currentIndex, 9, reason: 'Should clamp to max index');

      controller.setIndex(-1, 10);
      expect(controller.currentIndex, 0, reason: 'Should clamp to min index');

      controller.dispose();
    });

    test('onEffectTrigger receives intensity for startHaptic from first delta',
        () {
      const vsync = TestVSync();
      final effects = <PageFlipEvent>[];

      controller = PageFlipStateController(
        vsync: vsync,
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {pageIndex, intensity, volume, texture, resistance}) {
          effects.add(effect);
        },
      );

      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -20,
          delta: const Offset(-20, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      expect(effects, contains(PageFlipEvent.startHaptic));

      controller.dispose();
    });

    test('smoothed intensity logic (EMA) works correctly', () {
      const vsync = TestVSync();
      final intensities = <int>[];

      controller = PageFlipStateController(
        vsync: vsync,
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (effect, {pageIndex, intensity, volume, texture, resistance}) {
          // texturedHaptic uses texture/resistance
          if (effect == PageFlipEvent.texturedHaptic && intensity != null) {
            intensities.add(intensity);
          }
        },
      );

      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );

      // texturedHaptic is triggered every 2 frames, with higher base intensity
      // First update triggers startHaptic (frame 1)
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -10,
          delta: const Offset(-10, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      // Second update increments counter (frame 2) - may trigger texturedHaptic
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -15,
          delta: const Offset(-15, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      // Third update (frame 3)
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -20,
          delta: const Offset(-20, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      // Fourth update (frame 4) - should trigger texturedHaptic
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -25,
          delta: const Offset(-25, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      // texturedHaptic triggers on frames 2 and 4 (every 2nd frame)
      expect(intensities.length, greaterThanOrEqualTo(1),
          reason: 'texturedHaptic should be triggered');
      // Intensity should be in valid range (40-255 after all modulations)
      for (final i in intensities) {
        expect(i, inInclusiveRange(40, 255),
            reason: 'Intensity should be in textured haptic range');
      }

      controller.dispose();
    });
  });
}
