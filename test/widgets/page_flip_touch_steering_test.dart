import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/effects/page_flip_painter.dart';
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

    Widget buildApp({
      PageFlipConfig config = PageFlipConfig.defaultSettings,
      ValueChanged<int>? onPageChanged,
      VoidCallback? onFlipEnd,
      VoidCallback? onBuildPage,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: viewSize,
                child: PageFlipWidget(
                  itemCount: 3,
                  config: config.copyWith(enableSound: false),
                  onPageChanged: onPageChanged,
                  onFlipEnd: onFlipEnd,
                  itemBuilder: (context, index) {
                    onBuildPage?.call();
                    return ColoredBox(
                      color: Colors.primaries[index % Colors.primaries.length],
                    );
                  },
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

    for (final (completesTurn, reducedMotion) in [
      (true, false),
      (false, false),
      (true, true),
      (false, true),
    ]) {
      testWidgets(
        'a still finger release keeps the fold visible during '
        '${completesTurn ? 'completion' : 'snap-back'} reduced=$reducedMotion',
        (tester) async {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(disableAnimations: reducedMotion);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          final changedPages = <int>[];
          var flipEnds = 0;
          var pageBuilds = 0;
          await tester.pumpWidget(
            buildApp(
              config: const PageFlipConfig(enableHaptics: false),
              onPageChanged: changedPages.add,
              onFlipEnd: () => flipEnds++,
              onBuildPage: () => pageBuilds++,
            ),
          );
          await tester.pumpAndSettle();

          final gesture = await tester.startGesture(const Offset(550, 180));
          await gesture.moveBy(const Offset(-30, 0));
          await gesture.moveBy(Offset(completesTurn ? -180 : -40, 0));
          // Lift after the finger has stopped, so the distance decides.
          await tester.pump(const Duration(milliseconds: 80));

          final held = layerView(tester);
          expect(held.isDragging, isTrue);
          expect(held.dragProgress, inExclusiveRange(0.0, 1.0));
          expect(
            held.dragProgress >= PageFlipConfig.defaultSettings.cutoffForward,
            completesTurn,
          );

          final buildsWhileHeld = pageBuilds;
          await gesture.up();
          await tester.pump();

          final released = layerView(tester);
          expect(released.isDragging, isTrue);
          expect(released.dragProgress, held.dragProgress);
          expect(released.touchPosition, held.touchPosition);

          final fold = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is PageFlipPainter,
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(fold, findsOneWidget);
          await tester.pump(const Duration(milliseconds: 16));
          expect(fold, findsOneWidget);

          expect(
            pageBuilds,
            buildsWhileHeld,
            reason: 'Releasing the finger must not rebuild the live pages.',
          );
          final progress = layerView(tester).dragProgress;
          final target = completesTurn ? 1.0 : 0.0;
          final initialDistance = (target - held.dragProgress).abs();
          expect(
            (target - progress).abs(),
            inExclusiveRange(initialDistance / 2, initialDistance),
            reason: 'The fold should move toward its target without consuming '
                'most of the remaining travel in the first two frames.',
          );
          expect(changedPages, isEmpty);
          expect(flipEnds, 0);

          var previousProgress = progress;
          for (var frame = 0; frame < 90; frame++) {
            await tester.pump(const Duration(milliseconds: 8));
            final current = layerView(tester);
            if (!current.isDragging) break;
            expect(fold, findsOneWidget);
            expect(current.touchPosition, held.touchPosition);
            expect(
              current.dragProgress,
              completesTurn
                  ? greaterThanOrEqualTo(previousProgress)
                  : lessThanOrEqualTo(previousProgress),
            );
            previousProgress = current.dragProgress;
          }

          expect(fold, findsNothing);
          expect(layerView(tester).currentIndex, completesTurn ? 1 : 0);
          expect(changedPages, completesTurn ? [1] : <int>[]);
          expect(flipEnds, 1);
        },
      );
    }

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
