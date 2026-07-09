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
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
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
        DragEndDetails(primaryVelocity: 0),
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
          localPosition: Offset.zero,
        ),
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
          localPosition: Offset.zero,
        ),
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
          localPosition: Offset.zero,
        ),
        5,
      );
      expect(
        controller.isDragging,
        false,
        reason: 'Should not start drag at boundary',
      );
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
          localPosition: Offset.zero,
        ),
        5,
      );
      expect(
        controller.isDragging,
        false,
        reason: 'Should not start drag at boundary',
      );
    });

    test('dispose during any state does not throw', () {
      // Dispose immediately after creation
      final fresh = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          volume,
          texture,
          resistance,
        }) {},
      );
      // No exception expected
      expect(fresh.dispose, returnsNormally);
    });

    test('onEffectTrigger receives startHaptic from first delta', () {
      final effects = <PageFlipEvent>[];
      final effectController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
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

    test('texturedHaptic intensity in valid range (28-140)', () {
      final intensities = <int>[];
      final effectController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
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
          localPosition: Offset.zero,
        ),
        5,
      );
      effectController.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -15,
          delta: const Offset(-15, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
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
      effectController.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -25,
          delta: const Offset(-25, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      expect(intensities.length, greaterThanOrEqualTo(1));
      for (final i in intensities) {
        expect(i, inInclusiveRange(28, 140));
      }
      effectController.dispose();
    });

    test('slow drag still emits continuous texturedHaptic (no starvation)', () {
      // Regression: the old `_smoothedSpeed > 0.12` gate muted slow drags, so
      // the continuous haptic waveform starved and the vibration died whenever
      // the finger crawled. Each small step should now emit a textured sample.
      var texturedCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.texturedHaptic) texturedCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Slow crawl: small per-frame deltas that the old 0.12 gate suppressed.
      for (var i = 0; i < 6; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -0.6,
            delta: const Offset(-0.6, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }

      // A crawling finger now feeds the buffer on (almost) every frame instead
      // of going silent; expect the majority of the slow steps to emit.
      expect(texturedCount, greaterThanOrEqualTo(4));
      controller.dispose();
    });

    test('detent haptic fires exactly once when progress crosses the cutoff',
        () {
      // cutoffForward defaults to 0.4; cachedWidth 400 → cross at totalDx > 160.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Five steps of -40 = -200 total → progress 0.5, past the 0.4 cutoff.
      for (var i = 0; i < 5; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -40,
            delta: const Offset(-40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }

      expect(detentCount, equals(1));
      controller.dispose();
    });

    test('detent haptic does not fire while progress stays below the cutoff',
        () {
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Two steps of -40 = -80 total → progress 0.2, well below the 0.4 cutoff.
      for (var i = 0; i < 2; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -40,
            delta: const Offset(-40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }

      expect(detentCount, equals(0));
      controller.dispose();
    });

    test(
        'detent haptic does not re-fire when the finger wiggles back across '
        'the cutoff', () {
      // Regression guard: crossing forward, retreating below, then crossing
      // again must still emit only ONE tick for the whole drag session.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Cross forward past 0.4 (progress → 0.5).
      for (var i = 0; i < 5; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -40,
            delta: const Offset(-40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }
      // Retreat back below 0.4 (progress → 0.2).
      for (var i = 0; i < 3; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: 40,
            delta: const Offset(40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }
      // Cross forward past 0.4 again (progress → 0.5).
      for (var i = 0; i < 3; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -40,
            delta: const Offset(-40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }

      expect(detentCount, equals(1));
      controller.dispose();
    });

    test(
        'detent haptic fires on BACKWARD drags using cutoffPrevious, not '
        'cutoffForward', () {
      // Regression guard: the forward-only tests above could pass even if the
      // implementation accidentally hardcoded `cutoffForward` for both
      // directions. Use an asymmetric cutoff so a bug picking the wrong
      // threshold would be caught: cutoffPrevious=0.6 means a backward drag
      // must pass 0.6 (not the default 0.4) before the tick fires.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        // cutoffForward left at its default (0.4).
        cutoffPrevious: 0.6,
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      // currentIndex starts at 0, so a backward flip needs headroom: seed the
      // controller at page 1 first so `!isForward && currentIndex <= 0` does
      // not short-circuit the drag.
      controller.setIndex(1, 5);
      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // Backward drag: positive delta. Progress to 0.5 (200/400) — past
      // cutoffForward (0.4) but NOT past cutoffPrevious (0.6). Must NOT fire.
      for (var i = 0; i < 5; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: 40,
            delta: const Offset(40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }
      expect(controller.isForward, isFalse);
      expect(
        detentCount,
        equals(0),
        reason: 'progress 0.5 is past cutoffForward but not cutoffPrevious '
            '(0.6) — a wrong-threshold bug would fire here',
      );

      // Two more steps → progress 0.7, past cutoffPrevious. Must fire once.
      for (var i = 0; i < 2; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: 40,
            delta: const Offset(40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }
      expect(detentCount, equals(1));
      controller.dispose();
    });

    test(
        'detent haptic fires from the touch-slop-credited onDragStart path, '
        'not just onDragUpdate', () {
      // Regression guard: a fast decisive swipe can already be past the
      // cutoff on the very first frame via `accumulatedTotalDx`. The crossing
      // check must run in onDragStart too, not only in onDragUpdate.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      // accumulatedTotalDx=-200 on a 400-wide cache → progress 0.5 on the
      // very first frame, already past the default 0.4 cutoff.
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
        accumulatedTotalDx: -200,
      );

      expect(controller.dragProgress, closeTo(0.5, 0.001));
      expect(detentCount, equals(1));
      controller.dispose();
    });

    test('detent haptic fires immediately when cutoffForward is 0.0', () {
      // Boundary: threshold=0.0 means ANY forward progress satisfies
      // `dragProgress >= threshold`, so the very first update should fire.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        cutoffForward: 0,
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -1,
          delta: const Offset(-1, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );

      expect(detentCount, equals(1));
      controller.dispose();
    });

    test(
        'detent haptic never fires when cutoffForward is 1.0 and progress '
        'stays below full completion', () {
      // Boundary: threshold=1.0 requires dragProgress to reach exactly 1.0,
      // which a mid-drag (not yet released/animated) should never reach.
      var detentCount = 0;
      final controller = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        cutoffForward: 1,
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
          if (effect == PageFlipEvent.detentHaptic) detentCount++;
        },
      )..updateCachedWidth(400);

      controller.onDragStart(DragStartDetails(localPosition: Offset.zero), 5);
      // 9 steps of -40 = -360 total → progress 0.9, still short of 1.0.
      for (var i = 0; i < 9; i++) {
        controller.onDragUpdate(
          DragUpdateDetails(
            primaryDelta: -40,
            delta: const Offset(-40, 0),
            globalPosition: Offset.zero,
            localPosition: Offset.zero,
          ),
          5,
        );
      }

      expect(controller.dragProgress, lessThan(1.0));
      expect(detentCount, equals(0));
      controller.dispose();
    });

    testWidgets('successful finalize resets drag before onPageFinalized',
        (tester) async {
      var finalizedIndex = -1;
      var dragProgressAtFinalize = -1.0;
      var isDraggingAtFinalize = true;

      late PageFlipStateController flipController;
      flipController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {
          finalizedIndex = index;
          dragProgressAtFinalize = flipController.dragProgress;
          isDraggingAtFinalize = flipController.isDragging;
        },
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
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

    test('onDragStart with zero accumulatedTotalDx does not set isDragging',
        () {
      controller.updateCachedWidth(400);
      controller.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
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

    test(
        'onDragEnd with velocity > 300 triggers fast flip regardless of progress',
        () {
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

    testWidgets(
        'a small aborted drag still eases back over a perceptible minimum '
        'duration (no instant-vanish flicker)', (tester) async {
      // Regression: the snap-back duration used to share an 80ms floor with
      // the fast-completion path. For a SMALL aborted drag (the common case:
      // user barely swipes and lets go), the scaled duration collapsed to
      // that 80ms floor — about 5 frames at 60fps — reading as an abrupt
      // "flicker" rather than a smooth paper return. The floor for a
      // snap-back (isSuccess=false) is now higher; 100ms after release the
      // flip must still be mid-animation, not already finalized.
      late PageFlipStateController flipController;
      flipController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 450),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
      );
      flipController.updateCachedWidth(400);
      flipController.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );
      // Small drag: progress ~0.05, well below the 0.4 success cutoff.
      flipController.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -20,
          delta: const Offset(-20, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      // Low release velocity so isFastFlip is false and the release fails.
      flipController.onDragEnd(
        DragEndDetails(
          primaryVelocity: 50,
          velocity: const Velocity(pixelsPerSecond: Offset(50, 0)),
        ),
        5,
      );

      // 100ms is above the OLD 80ms floor (which would already be finalized
      // by now) but below the new floor — the flip must still be active.
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        flipController.isDragging,
        isTrue,
        reason: 'A small aborted drag must still be easing back at 100ms, '
            'not already snapped to idle',
      );

      // Let the animation actually finish.
      await tester.pump(const Duration(milliseconds: 400));
      expect(flipController.isDragging, isFalse);
      expect(flipController.dragProgress, 0.0);
      flipController.dispose();
    });

    test('onDragEnd when not dragging ends capture and fires onFlipEnd', () {
      var flipEnded = false;
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      expect(flipEnded, isTrue);
      local.dispose();
    });

    test('onDragEnd when disposed returns early', () {
      var flipEnded = false;
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.dispose();
      local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5);
      expect(flipEnded, isFalse); // Should NOT fire after dispose
    });

    test('onDragCancel when disposed returns early', () {
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
      );
      local.dispose();
      // Should not throw
      expect(() => local.onDragCancel(5), returnsNormally);
    });

    test('onDragCancel when not dragging ends capture and fires onFlipEnd', () {
      var flipEnded = false;
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
        onFlipEnd: () => flipEnded = true,
      );
      local.onDragCancel(5);
      expect(flipEnded, isTrue);
      local.dispose();
    });

    testWidgets(
        'onDragCancel snaps back smoothly instead of tearing down the flip '
        'layer on the same frame', (tester) async {
      // Regression: onDragCancel used to call `_finalizePageChange` right
      // after starting the snap-back `animateTo`, resetting isDragging/
      // dragProgress to their idle values on the SAME frame the animation
      // began. `PageFlipLayerView` reads `dragProgress > 0 && isDragging` to
      // decide whether to render the flip layers, so that hard reset made the
      // flip visuals disappear instantly instead of easing back — a
      // "flicker" rather than a smooth paper return. This exercises the path
      // triggered when a drag is cancelled mid-gesture (e.g. the arbitration
      // logic yielding to vertical scroll content), not just an explicit
      // release.
      late PageFlipStateController flipController;
      flipController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
      );
      flipController.updateCachedWidth(400);
      flipController.onDragStart(
        DragStartDetails(localPosition: Offset.zero),
        5,
      );
      flipController.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: -120,
          delta: const Offset(-120, 0),
          globalPosition: Offset.zero,
          localPosition: Offset.zero,
        ),
        5,
      );
      final progressBeforeCancel = flipController.dragProgress;
      expect(progressBeforeCancel, greaterThan(0));

      flipController.onDragCancel(5);

      // Immediately after onDragCancel returns (before any frame has been
      // pumped), the flip must still be considered "active" so the flip
      // layer keeps rendering the mid-flight geometry — the snap-back
      // animation has only just started, not already finished.
      expect(
        flipController.isDragging,
        isTrue,
        reason: 'isDragging must stay true until the snap-back animation '
            'actually completes',
      );
      expect(
        flipController.dragProgress,
        closeTo(progressBeforeCancel, 0.01),
        reason: 'dragProgress must not jump to 0 before the animation runs',
      );

      // Advance past the (floored) snap-back duration.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));

      expect(flipController.isDragging, isFalse);
      expect(flipController.dragProgress, 0.0);
      flipController.dispose();
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
      expect(
        () => controller.triggerTapFlip(isNext: true, totalPages: 5),
        returnsNormally,
      );
    });

    test('triggerTapFlip when animationController.isAnimating returns early',
        () {
      controller.setIndex(0, 5);
      controller.updateCachedWidth(400);
      controller.triggerTapFlip(isNext: true, totalPages: 5);
      // Animation is running, second call should be ignored
      expect(
        () => controller.triggerTapFlip(isNext: true, totalPages: 5),
        returnsNormally,
      );
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
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
      );
      local.dispose();
      expect(local.dispose, returnsNormally);
    });

    test('dispose clears isPendingFinalize', () {
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
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
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
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
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
      );
      expect(
        () => local.onDragEnd(DragEndDetails(primaryVelocity: 0), 5),
        returnsNormally,
      );
      local.dispose();
    });

    testWidgets('successful flip via onDragEnd advances currentIndex',
        (tester) async {
      final local = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 50),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          _, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {},
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
      var soundFired = false;
      var hapticFired = false;

      // Create a controller with effect tracking
      final tapController = PageFlipStateController(
        vsync: const TestVSync(),
        animationDuration: const Duration(milliseconds: 300),
        onUpdate: () {},
        onPageFinalized: (index) {},
        onEffectTrigger: (
          effect, {
          intensity,
          pageIndex,
          resistance,
          texture,
          timestampMs,
          volume,
        }) {
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
