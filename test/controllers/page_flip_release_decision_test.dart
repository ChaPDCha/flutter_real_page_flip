import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

/// Regression coverage for the 2.3.2 gesture/state fixes:
/// - release direction decides a fling (reverse flick cancels),
/// - a gesture refused during a settle cannot re-decide that settle,
/// - tap flips start from the vertical centre (level fold),
/// - timing/threshold settings follow config updates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldCommitFlip', () {
    test('fast flick toward completion commits from a small drag', () {
      expect(
        shouldCommitFlip(
          isForward: true,
          progress: 0.05,
          releaseVelocityPxPerSecond: -800,
          threshold: 0.4,
        ),
        isTrue,
      );
      expect(
        shouldCommitFlip(
          isForward: false,
          progress: 0.05,
          releaseVelocityPxPerSecond: 800,
          threshold: 0.4,
        ),
        isTrue,
      );
    });

    test('fast flick AWAY from completion cancels a large drag', () {
      expect(
        shouldCommitFlip(
          isForward: true,
          progress: 0.9,
          releaseVelocityPxPerSecond: 800,
          threshold: 0.4,
        ),
        isFalse,
        reason: 'Throwing a forward page back to the right must cancel it',
      );
      expect(
        shouldCommitFlip(
          isForward: false,
          progress: 0.9,
          releaseVelocityPxPerSecond: -800,
          threshold: 0.4,
        ),
        isFalse,
      );
    });

    test('slow release falls back to distance threshold', () {
      expect(
        shouldCommitFlip(
          isForward: true,
          progress: 0.6,
          releaseVelocityPxPerSecond: 100,
          threshold: 0.4,
        ),
        isTrue,
      );
      expect(
        shouldCommitFlip(
          isForward: true,
          progress: 0.3,
          releaseVelocityPxPerSecond: -100,
          threshold: 0.4,
        ),
        isFalse,
      );
    });

    test('non-finite velocity is treated as a still release', () {
      expect(
        shouldCommitFlip(
          isForward: true,
          progress: 0.6,
          releaseVelocityPxPerSecond: double.nan,
          threshold: 0.4,
        ),
        isTrue,
      );
    });
  });

  group('PageFlipStateController release/settle', () {
    late PageFlipStateController controller;
    late List<int> finalized;
    late int flipStarts;
    late int flipEnds;

    PageFlipStateController build({
      double cutoffForward = 0.4,
    }) =>
        PageFlipStateController(
          vsync: const TestVSync(),
          animationDuration: const Duration(milliseconds: 300),
          cutoffForward: cutoffForward,
          onUpdate: () {},
          onPageFinalized: finalized.add,
          onFlipStart: () => flipStarts++,
          onFlipEnd: () => flipEnds++,
          onEffectTrigger: (
            effect, {
            intensity,
            volume,
            texture,
            resistance,
          }) {},
        );

    setUp(() {
      finalized = <int>[];
      flipStarts = 0;
      flipEnds = 0;
      controller = build()..updateCachedWidth(400);
    });

    tearDown(() => controller.dispose());

    void dragForward(double dx) {
      expect(
        controller.onDragStart(
          DragStartDetails(localPosition: const Offset(350, 300)),
          5,
          accumulatedTotalDx: -10,
        ),
        isTrue,
      );
      controller.onDragUpdate(
        DragUpdateDetails(
          primaryDelta: dx,
          delta: Offset(dx, 0),
          globalPosition: Offset.zero,
          localPosition: Offset(340 + dx, 300),
        ),
        5,
      );
    }

    testWidgets('reverse flick after a long forward drag snaps back',
        (tester) async {
      dragForward(-230); // progress ≈ 0.6, past the 0.4 cutoff
      expect(controller.dragProgress, greaterThan(0.5));

      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: 900,
          velocity: const Velocity(pixelsPerSecond: Offset(900, 0)),
        ),
        5,
      );
      await tester.pumpAndSettle();

      expect(finalized, isEmpty, reason: 'Reverse flick must cancel');
      expect(controller.currentIndex, 0);
      expect(controller.isDragging, isFalse);
    });

    testWidgets('a gesture during a snap-back cannot commit the turn',
        (tester) async {
      dragForward(-40); // progress 0.125
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: 0,
          velocity: Velocity.zero,
        ),
        5,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.isSettling, isTrue);

      // Second gesture while settling: refused at start...
      expect(
        controller.onDragStart(
          DragStartDetails(localPosition: const Offset(350, 300)),
          5,
          accumulatedTotalDx: -20,
        ),
        isFalse,
      );
      // ...and its fast forward flick must not re-decide the settle.
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -2000,
          velocity: const Velocity(pixelsPerSecond: Offset(-2000, 0)),
        ),
        5,
      );
      await tester.pumpAndSettle();

      expect(finalized, isEmpty);
      expect(controller.currentIndex, 0);
      expect(flipStarts, 1, reason: 'Refused gesture fires no onFlipStart');
      expect(flipEnds, 1, reason: 'Exactly one onFlipEnd for one flip');
    });

    testWidgets('a gesture during a committed settle cannot cancel it',
        (tester) async {
      dragForward(-240);
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: -600,
          velocity: const Velocity(pixelsPerSecond: Offset(-600, 0)),
        ),
        5,
      );
      await tester.pump(const Duration(milliseconds: 16));

      controller.onDragCancel(5);
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: 2000,
          velocity: const Velocity(pixelsPerSecond: Offset(2000, 0)),
        ),
        5,
      );
      await tester.pumpAndSettle();

      expect(finalized, <int>[1]);
      expect(flipEnds, 1);
    });

    testWidgets('tap flip starts from the vertical centre of the viewport',
        (tester) async {
      // Landscape: width 900, height 400. The old code used the WIDTH as the
      // y coordinate (900 > 400 → clamped to the bottom edge → tilted fold).
      controller
        ..updateCachedWidth(900)
        ..updateCachedHeight(400)
        ..triggerTapFlip(isNext: true, totalPages: 5);

      expect(controller.touchPosition, const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(finalized, <int>[1]);
    });

    testWidgets('tap flip before first layout reports a non-finite y',
        (tester) async {
      controller.triggerTapFlip(isNext: true, totalPages: 5);
      // The layer view maps non-finite coordinates to the vertical centre.
      expect(controller.touchPosition.dy.isFinite, isFalse);
      await tester.pumpAndSettle();
    });

    testWidgets('updateSettings changes the cutoff used at release',
        (tester) async {
      controller.updateSettings(
        animationDuration: const Duration(milliseconds: 200),
        cutoffForward: 0.8,
        cutoffPrevious: 0.4,
      );
      expect(
        controller.animationController.duration,
        const Duration(milliseconds: 200),
      );

      dragForward(-230); // ≈ 0.6: past the old 0.4, short of the new 0.8
      controller.onDragEnd(
        DragEndDetails(primaryVelocity: 0, velocity: Velocity.zero),
        5,
      );
      await tester.pumpAndSettle();

      expect(finalized, isEmpty);
    });
  });
}
