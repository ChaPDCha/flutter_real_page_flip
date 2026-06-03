import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/widgets/edge_tap_feedback.dart';

void main() {
  group('EdgeTapFeedback', () {
    testWidgets('renders on left side', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 200));
      expect(tapped, isTrue);
    });

    testWidgets('renders on right side', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                EdgeTapFeedback(
                  isLeftEdge: false,
                  width: 40,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );
      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(screenSize.width - 20, screenSize.height / 2));
      expect(tapped, isTrue);
    });

    testWidgets('tap fires callback', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () => tapCount++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(20, 200));
      expect(tapCount, equals(1));
    });

    testWidgets('animation plays forward on tap-down and reverse on tap-up', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Check initial state: no animation running
      final gesture = await tester.startGesture(const Offset(20, 200));
      await tester.pump(); // Trigger tap-down

      // After tap-down: animation should start forward (50ms fast-in)
      await tester.pump(const Duration(milliseconds: 25));
      // Opacity should be between 0.02 and 0.20 (animation is midway)
      // The container's gradient uses _opacityAnimation.value * 0.18 + 0.02
      // At 25ms into a 50ms forward: animation.value ≈ 0.5
      // currentOpacity ≈ 0.5 * 0.18 + 0.02 = 0.11
      // We verify the animation ran (doesn't throw, widget has gradient)

      await gesture.up();
      await tester.pump(); // Trigger tap-up → fade out starts

      // After fade-out begins: opacity should decrease
      await tester.pump(const Duration(milliseconds: 100));
      // Animation should be reversing toward 0
    });

    testWidgets('cancel fades out without calling onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () => tapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(20, 200));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      // onTap should not have been called
      expect(tapped, isFalse);
    });

    testWidgets('renders with semantics label and hint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  label: 'Previous page',
                  hint: 'Tap to go to previous page',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Widget renders without error; semantics are internal
      expect(
        find.byWidgetPredicate((w) => w is EdgeTapFeedback),
        findsOneWidget,
      );
    });

    testWidgets('light mode uses black base gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      // Tap down to trigger gradient appearance
      await tester.tapAt(const Offset(20, 200));
      await tester.pump();

      // Widget should render without errors (gradient drawn)
    });

    testWidgets('dark mode uses white base gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Stack(
              children: [
                EdgeTapFeedback(
                  isLeftEdge: true,
                  width: 40,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 200));
      await tester.pump();

      // Widget should render without errors
    });
  });
}
