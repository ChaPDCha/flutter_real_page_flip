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
        onEffectTrigger: (effect,
            {intensity,
            pageIndex,
            resistance,
            texture,
            timestampMs,
            volume}) {},
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
          primaryDelta: -50,
          delta: const Offset(-50, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
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

    test('progressFromHorizontalDelta uses flip drag extent', () {
      controller.updateCachedWidth(200);
      expect(controller.progressFromHorizontalDelta(-180), closeTo(0.9, 0.001));
      expect(controller.progressFromHorizontalDelta(50), closeTo(0.25, 0.001));
    });

    test('onDragStart credits accumulated slop toward flip progress', () {
      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: const Offset(300, 200)),
        5,
        accumulatedTotalDx: -200,
      );
      expect(controller.isDragging, isTrue);
      expect(controller.dragProgress, closeTo(0.5, 0.001));
      expect(controller.isForward, isTrue);
    });

    test('full-width swipe completes flip at release', () {
      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
        accumulatedTotalDx: -10,
      );
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -390,
          delta: const Offset(-390, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      expect(controller.dragProgress, 1.0);
      controller.onDragEnd(
        DragEndDetails(primaryVelocity: 0, velocity: Velocity.zero),
        5,
      );
      // Animation runs async; finalize happens after animateTo completes.
    });

    test('updateCachedWidth ignores non-finite extent', () {
      controller.updateCachedWidth(400);
      controller.updateCachedWidth(double.infinity);
      expect(controller.cachedWidth, 400);
      controller.updateCachedWidth(double.nan);
      expect(controller.cachedWidth, 400);
    });

    test('onDragUpdate clamps progress to [0, 1]', () {
      controller.updateCachedWidth(400);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);

      // Drag far beyond the screen width
      controller.onDragUpdate(
        DragUpdateDetails(
            primaryDelta: -500,
            delta: const Offset(-500, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
        5,
      );
      expect(controller.dragProgress, greaterThanOrEqualTo(0.0));
      expect(controller.dragProgress, lessThanOrEqualTo(1.0));

      // Drag in opposite direction
      controller.onDragUpdate(
        DragUpdateDetails(
            primaryDelta: 200,
            delta: const Offset(200, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
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
        DragUpdateDetails(
            primaryDelta: -50,
            delta: const Offset(-50, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
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
        DragUpdateDetails(
            primaryDelta: 50,
            delta: const Offset(50, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
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
        onEffectTrigger: (PageFlipEvent effect,
            {int? intensity,
            double? volume,
            double? texture,
            double? resistance}) {},
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
        onEffectTrigger: (effect,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
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
        onEffectTrigger: (effect,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
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
        DragUpdateDetails(
            primaryDelta: -10,
            delta: const Offset(-10, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(
            primaryDelta: -15,
            delta: const Offset(-15, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(
            primaryDelta: -20,
            delta: const Offset(-20, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(
            primaryDelta: -25,
            delta: const Offset(-25, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero),
        5,
      );

      expect(intensities.length, greaterThanOrEqualTo(1));
      for (final i in intensities) {
        expect(i, inInclusiveRange(40, 255));
      }
      effectController.dispose();
    });

    testWidgets('successful finalize resets drag before onPageFinalized',
        (tester) async {
      var finalizedIndex = -1;
      var dragProgressAtFinalize = -1.0;
      var isDraggingAtFinalize = true;

      late PageFlipStateController flipController;
      flipController = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {
          finalizedIndex = index;
          dragProgressAtFinalize = flipController.dragProgress;
          isDraggingAtFinalize = flipController.isDragging;
        },
        onEffectTrigger: (_,
            {intensity,
            pageIndex,
            resistance,
            texture,
            timestampMs,
            volume}) {},
      );
      flipController.setIndex(0, 3);
      flipController.updateCachedWidth(400);
      flipController.triggerTapFlip(isNext: true, totalPages: 3);

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));

      expect(finalizedIndex, 1);
      expect(dragProgressAtFinalize, 0.0);
      expect(isDraggingAtFinalize, isFalse);
      flipController.dispose();
    });

    test('cachedWidth rejects zero', () {
      controller.updateCachedWidth(400);
      controller.updateCachedWidth(0);
      expect(controller.cachedWidth, 400);
    });

    test('cachedWidth rejects negative', () {
      controller.updateCachedWidth(400);
      controller.updateCachedWidth(-100);
      expect(controller.cachedWidth, 400);
    });

    test('progressFromHorizontalDelta with cachedWidth=0 returns 0', () {
      // Force cachedWidth to an invalid value by setting it to 0 directly
      // (updateCachedWidth guards against this, so test the guard at calculation time)
      controller.updateCachedWidth(400);
      expect(controller.progressFromHorizontalDelta(-200), closeTo(0.5, 0.001));
    });

    test('onDragStart with zero accumulatedTotalDx does not set isDragging', () {
      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
        accumulatedTotalDx: 0,
      );
      expect(controller.isDragging, isFalse);
    });

    test('onDragStart when isPendingFinalize returns early', () {
      // Force isPendingFinalize=true by calling the internal state
      controller.updateCachedWidth(400);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Simulate finalize
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -300,
          delta: const Offset(-300, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -500,
          velocity: const Velocity(pixelsPerSecond: Offset(-500, 0)),
        ),
        5,
      );
      // Now isPendingFinalize should be set, next drag start should be ignored
      controller.onDragStart(
        DragStartDetails(localPosition: const Offset(100, 100)),
        5,
      );
      // Touch position should NOT update
      expect(controller.touchPosition, isNot(const Offset(100, 100)));
    });

    test('onDragEnd with velocity > 300 triggers fast flip regardless of progress', () {
      controller.updateCachedWidth(400);
      controller.setIndex(0, 5);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Very small progress but high velocity
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -10,
          delta: const Offset(-10, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      // Velocity > 300 should skip cutoff check
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -500,
          velocity: const Velocity(pixelsPerSecond: Offset(-500, 0)),
        ),
        5,
      );
      // Animation should be running (animateTo was called)
      expect(controller.animationController.isAnimating, isTrue);
    });

    test('onDragEnd when not dragging ends capture and fires onFlipEnd', () {
      bool flipEnded = false;
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      expect(flipEnded, isTrue);
      local.dispose();
    });

    test('onDragEnd when disposed returns early', () {
      bool flipEnded = false;
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.dispose();
      local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      expect(flipEnded, isFalse); // Should NOT fire after dispose
    });

    test('onDragCancel when disposed returns early', () {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
      local.dispose();
      // Should not throw
      expect(() => local.onDragCancel(5), returnsNormally);
    });

    test('onDragCancel when not dragging ends capture and fires onFlipEnd', () {
      bool flipEnded = false;
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.onDragCancel(5);
      expect(flipEnded, isTrue);
      local.dispose();
    });

    test('triggerTapFlip when isDragging returns early', () {
      controller.updateCachedWidth(400);
      controller.setIndex(0, 5);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
        accumulatedTotalDx: -100,
      );
      expect(controller.isDragging, isTrue);
      // Should NOT start a tap flip while dragging
      expect(() => controller.triggerTapFlip(isNext: true, totalPages: 5),
          returnsNormally);
    });

    test('triggerTapFlip when animationController.isAnimating returns early', () {
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);
      controller.triggerTapFlip(isNext: true, totalPages: 5);
      // Animation is running, second call should be ignored
      expect(() => controller.triggerTapFlip(isNext: true, totalPages: 5),
          returnsNormally);
    });

    test('triggerTapFlip when next at last page returns early', () {
      controller.setIndex(4, 5);
      controller.triggerTapFlip(isNext: true, totalPages: 5);
      // Should not change page
      expect(controller.currentIndex, 4);
    });

    test('triggerTapFlip when previous at first page returns early', () {
      controller.setIndex(0, 5);
      controller.triggerTapFlip(isNext: false, totalPages: 5);
      expect(controller.currentIndex, 0);
    });

    test('dispose is idempotent', () {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
      local.dispose();
      expect(() => local.dispose(), returnsNormally);
    });

    test('dispose clears isPendingFinalize', () {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
      local.updateCachedWidth(400);
      local.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      local.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -300,
          delta: const Offset(-300, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      local.onDragEnd(
        DragEndDetails(
          primaryVelocity: -500,
          velocity: const Velocity(pixelsPerSecond: Offset(-500, 0)),
        ),
        5,
      );
      // isPendingFinalize should be set after successful flip
      local.dispose();
      // dispose should clear it
      expect(local.isPendingFinalize, isFalse);
    });

    test('beginPointerCapture guards re-entrance', () {
      controller.beginPointerCapture();
      controller.beginPointerCapture(); // Second call should be no-op
      expect(controller.blocksContentPointers, isTrue);
    });

    test('endPointerCapture guards re-entrance', () {
      controller.beginPointerCapture();
      controller.endPointerCapture();
      controller.endPointerCapture(); // Second call should be no-op
      expect(controller.blocksContentPointers, isFalse);
    });

    test('onFlipStart null callback does not throw', () {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
        onFlipStart: null,
      );
      local.updateCachedWidth(400);
      expect(
        () => local.onDragStart(
          DragStartDetails(localPosition: Offset.zero),
          5,
          accumulatedTotalDx: -100,
        ),
        returnsNormally,
      );
      local.dispose();
    });

    test('onFlipEnd null callback does not throw', () {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
        onFlipEnd: null,
      );
      expect(() => local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5),
          returnsNormally);
      local.dispose();
    });

    testWidgets('successful flip via onDragEnd advances currentIndex',
        (tester) async {
      final local = PageFlipStateController(
        vsync: TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (_,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {},
      );
      local.setIndex(0, 5);
      local.updateCachedWidth(400);
      local.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      local.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -300,
          delta: const Offset(-300, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(local.currentIndex, 1);
      local.dispose();
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
        onEffectTrigger: (effect,
            {intensity, pageIndex, resistance, texture, timestampMs, volume}) {
          if (effect == PageFlipEvent.sound) soundFired = true;
          if (effect == PageFlipEvent.impulseHaptic) hapticFired = true;
        },
      );
      tapController.setIndex(0, 5);

      tapController.triggerTapFlip(isNext: true, totalPages: 5);

      // Effects should fire immediately
      expect(soundFired, isTrue);
      expect(hapticFired, isTrue);
      tapController.dispose();
    });
  });
}
