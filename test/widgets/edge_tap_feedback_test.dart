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

      // Should have Positioned with left: 0
      // Tap inside left edge
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

      // Tap inside right edge area
      // The Positioned widget has right: 0 so its x starts at screen width - 40
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
  });
}
