import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

void main() {
  group('PageFlipWidget Edge Taps', () {
    testWidgets('Right edge tap triggers next page', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            // Default edgeTapWidthRatio is 0.1
            config: const PageFlipConfig(edgeTapWidthRatio: 0.1),
            itemCount: 2,
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      // Verify initial state
      expect(changedPage, null);

      // Tap on the right edge (e.g. at 95% width)
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(width * 0.95, height / 2));
      await tester.pumpAndSettle();

      // Expect page to change to 1
      expect(changedPage, 1);
    });

    testWidgets('Left edge tap triggers previous page', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 1, // Start at page 1
            config: const PageFlipConfig(edgeTapWidthRatio: 0.1),
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            itemCount: 2,
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      // Verify initial state
      expect(changedPage, null);

      // Tap on the left edge (e.g. at 5% width)
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(width * 0.05, height / 2));
      await tester.pumpAndSettle();

      // Expect page to change back to 0
      expect(changedPage, 0);
    });

    testWidgets('Center tap does NOT trigger page flip', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            config: const PageFlipConfig(edgeTapWidthRatio: 0.1),
            itemCount: 2,
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      // Tap center (e.g. at 50% width)
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(width * 0.5, height / 2));
      await tester.pumpAndSettle();

      // Expect NO page change
      expect(changedPage, null);
    });

    testWidgets('Edge tap disabled when edgeTapWidthRatio is 0',
        (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            config: const PageFlipConfig(edgeTapWidthRatio: 0.0), // Disable
            itemCount: 2,
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      // Tap right edge
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      await tester.tapAt(Offset(width * 0.95, height / 2));
      await tester.pumpAndSettle();

      // Expect NO page change
      expect(changedPage, null);
    });

    testWidgets('Drag still works on top of edge area', (tester) async {
      int? changedPage;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            config: const PageFlipConfig(
                edgeTapWidthRatio: 0.1, sensitivity: 0.5, enableSwipe: true),
            itemCount: 2,
            itemBuilder: (context, index) => [
              Container(color: Colors.blue),
              Container(color: Colors.red),
            ][index],
            onPageChanged: (index) {
              changedPage = index;
            },
          ),
        ),
      );

      // Drag from right edge to center
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final height =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      // Start drag at 95% (inside tap area)
      final start = Offset(width * 0.95, height / 2);
      final end = Offset(width * 0.5, height / 2);

      await tester.dragFrom(start, end - start);
      await tester.pumpAndSettle();

      // Should flip to next page
      expect(changedPage, 1);
    });
  });
}
