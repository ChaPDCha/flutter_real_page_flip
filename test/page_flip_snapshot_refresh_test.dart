import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  Widget buildFlip({
    required PageFlipController controller,
    required Object contentRevision,
    DevicePerformanceProfile performanceProfile =
        DevicePerformanceProfile.medium,
    double? maxSnapshotPixelRatio,
  }) =>
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: PageFlipWidget(
            key: const ValueKey<String>('stable-flip'),
            controller: controller,
            contentRevision: contentRevision,
            initialIndex: 2,
            itemCount: 8,
            config: PageFlipConfig(
              duration: const Duration(milliseconds: 120),
              enableHaptics: false,
              enableSound: false,
              skipTapAnimation: false,
              snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.whenDirty,
              performanceProfile: performanceProfile,
              maxSnapshotPixelRatio: maxSnapshotPixelRatio,
            ),
            itemBuilder: (context, index) => ColoredBox(
              color: Color(0xFF000000 | (index * 0x101010)),
              child: Text('Revision $contentRevision / page $index'),
            ),
          ),
        ),
      );

  testWidgets(
    'contentRevision refresh preserves state and current page',
    (tester) async {
      final controller = PageFlipController();

      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 0),
      );
      await tester.pumpAndSettle();
      final stateBefore = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );

      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 1),
      );
      await tester.pumpAndSettle();
      final stateAfter = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );

      expect(stateAfter, same(stateBefore));
      expect(stateAfter.controller.currentIndex, 2);
      expect(find.text('Revision 1 / page 2'), findsOneWidget);
      expect(stateAfter.debugDirtySnapshotIndices, isEmpty);
    },
  );

  testWidgets(
    'capture resolution config refreshes the window without resetting state',
    (tester) async {
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 0),
      );
      await tester.pumpAndSettle();
      final stateBefore = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      var capturesBefore = stateBefore.debugAsyncSnapshotCaptureCount;

      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          contentRevision: 0,
          performanceProfile: DevicePerformanceProfile.high,
        ),
      );
      await tester.pumpAndSettle();
      var stateAfter = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      expect(stateAfter, same(stateBefore));
      expect(stateAfter.controller.currentIndex, 2);
      expect(stateAfter.debugDirtySnapshotIndices, isEmpty);
      expect(stateAfter.debugAsyncSnapshotCaptureCount - capturesBefore, 3);

      capturesBefore = stateAfter.debugAsyncSnapshotCaptureCount;
      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          contentRevision: 0,
          performanceProfile: DevicePerformanceProfile.high,
          maxSnapshotPixelRatio: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      stateAfter = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      expect(stateAfter, same(stateBefore));
      expect(stateAfter.controller.currentIndex, 2);
      expect(stateAfter.debugDirtySnapshotIndices, isEmpty);
      expect(stateAfter.debugAsyncSnapshotCaptureCount - capturesBefore, 3);

      capturesBefore = stateAfter.debugAsyncSnapshotCaptureCount;
      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          contentRevision: 1,
          maxSnapshotPixelRatio: 2,
        ),
      );
      await tester.pumpAndSettle();
      stateAfter = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      expect(stateAfter, same(stateBefore));
      expect(stateAfter.controller.currentIndex, 2);
      expect(stateAfter.debugDirtySnapshotIndices, isEmpty);
      expect(
        stateAfter.debugAsyncSnapshotCaptureCount - capturesBefore,
        3,
        reason: 'content and capture-resolution changes must share one refresh',
      );
    },
  );

  testWidgets(
    'whenDirty skips synchronous capture for clean and prewarmed pages',
    (tester) async {
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 0),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(state.debugSyncSnapshotCaptureCount, 0);

      controller.markCurrentPageDirty();
      await tester.pumpAndSettle();
      expect(state.debugDirtySnapshotIndices, isEmpty);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(state.debugSyncSnapshotCaptureCount, 0);
    },
  );

  testWidgets(
    'repeated dirty marks are coalesced into one asynchronous refresh',
    (tester) async {
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 0),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      final capturesBefore = state.debugAsyncSnapshotCaptureCount;

      for (var i = 0; i < 5; i++) {
        controller.markCurrentPageDirty();
      }
      await tester.pumpAndSettle();

      expect(state.debugDirtySnapshotIndices, isEmpty);
      expect(state.debugAsyncSnapshotCaptureCount - capturesBefore, 1);
    },
  );

  testWidgets(
    'dirty-only invalidation defers capture until the next flip fallback',
    (tester) async {
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(controller: controller, contentRevision: 0),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      final asyncCapturesBefore = state.debugAsyncSnapshotCaptureCount;
      final syncCapturesBefore = state.debugSyncSnapshotCaptureCount;

      controller.markPageDirty(2, prewarm: false);
      controller.markCurrentPageDirty(prewarm: false);
      await tester.pumpAndSettle();

      expect(state.debugDirtySnapshotIndices, contains(2));
      expect(state.debugAsyncSnapshotCaptureCount, asyncCapturesBefore);
      expect(state.debugSyncSnapshotCaptureCount, syncCapturesBefore);

      controller.nextPage();
      await tester.pumpAndSettle();

      expect(state.debugSyncSnapshotCaptureCount, syncCapturesBefore + 1);
      expect(state.debugDirtySnapshotIndices, isNot(contains(2)));
    },
  );

  testWidgets(
    'scroll end prewarms the current snapshot before the next flip',
    (tester) async {
      final controller = PageFlipController();
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 480,
            child: PageFlipWidget(
              controller: controller,
              itemCount: 4,
              config: const PageFlipConfig(
                duration: Duration(milliseconds: 120),
                enableHaptics: false,
                enableSound: false,
                skipTapAnimation: false,
                snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.whenDirty,
              ),
              itemBuilder: (context, index) => ListView(
                controller: index == 0 ? scrollController : null,
                children: [
                  for (var row = 0; row < 12; row++)
                    SizedBox(height: 100, child: Text('Page $index row $row')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      final capturesBefore = state.debugAsyncSnapshotCaptureCount;

      scrollController.jumpTo(250);
      await tester.pumpAndSettle();

      expect(state.debugDirtySnapshotIndices, isEmpty);
      expect(state.debugAsyncSnapshotCaptureCount - capturesBefore, 1);

      controller.nextPage();
      await tester.pumpAndSettle();
      expect(state.debugSyncSnapshotCaptureCount, 0);
    },
  );

  test('snapshot refresh config is copied and normalized', () {
    const config = PageFlipConfig(
      snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.whenDirty,
      maxSnapshotPixelRatio: 2.25,
    );

    expect(
      config.copyWith().snapshotRefreshPolicy,
      PageFlipSnapshotRefreshPolicy.whenDirty,
    );
    expect(config.copyWith().maxSnapshotPixelRatio, 2.25);
    expect(
      const PageFlipConfig(maxSnapshotPixelRatio: double.infinity)
          .normalized
          .maxSnapshotPixelRatio,
      isNull,
    );
  });
}
