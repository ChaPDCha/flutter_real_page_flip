import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

void main() {
  Widget buildFlip({
    required PageFlipController controller,
    required DevicePerformanceProfile performanceProfile,
    required DevicePerformanceProfile snapshotPerformanceProfile,
    required double maxSnapshotPixelRatio,
  }) =>
      MaterialApp(
        home: PageFlipWidget(
          key: const ValueKey<String>('snapshot-profile-flip'),
          controller: controller,
          contentRevision: 0,
          initialIndex: 2,
          itemCount: 8,
          config: PageFlipConfig(
            duration: const Duration(milliseconds: 120),
            enableHaptics: false,
            enableSound: false,
            skipTapAnimation: false,
            snapshotRefreshPolicy: PageFlipSnapshotRefreshPolicy.whenDirty,
            performanceProfile: performanceProfile,
            snapshotPerformanceProfile: snapshotPerformanceProfile,
            maxSnapshotPixelRatio: maxSnapshotPixelRatio,
          ),
          itemBuilder: (context, index) => ColoredBox(
            color: Color(0xFF000000 | (index * 0x101010)),
            child: Text('Page $index'),
          ),
        ),
      );

  void useDpr3Phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(960, 1440);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'low rendering reuses equal-resolution snapshots and preserves pixels',
    (tester) async {
      useDpr3Phone(tester);
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          performanceProfile: DevicePerformanceProfile.high,
          snapshotPerformanceProfile: DevicePerformanceProfile.high,
          maxSnapshotPixelRatio: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      final capturesBeforeEffectDowngrade =
          state.debugAsyncSnapshotCaptureCount;
      expect(
        state.debugSnapshotPixelSize(2),
        (width: 480, height: 720),
      );

      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          performanceProfile: DevicePerformanceProfile.low,
          snapshotPerformanceProfile: DevicePerformanceProfile.medium,
          maxSnapshotPixelRatio: 1.5,
        ),
      );
      await tester.pumpAndSettle();

      final layer = tester.widget<PageFlipLayerView>(
        find.byType(PageFlipLayerView),
      );
      expect(layer.performanceProfile, DevicePerformanceProfile.low);
      expect(
        state.debugAsyncSnapshotCaptureCount - capturesBeforeEffectDowngrade,
        0,
        reason:
            'A profile change that still resolves to 1.5 DPR must not trigger '
            'three redundant GPU readbacks.',
      );
      expect(
        state.debugSnapshotPixelSize(2),
        (width: 480, height: 720),
      );

      final capturesBeforeResolutionIncrease =
          state.debugAsyncSnapshotCaptureCount;
      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          performanceProfile: DevicePerformanceProfile.low,
          snapshotPerformanceProfile: DevicePerformanceProfile.medium,
          maxSnapshotPixelRatio: 1.75,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        state.debugAsyncSnapshotCaptureCount - capturesBeforeResolutionIncrease,
        3,
      );
      expect(
        state.debugSnapshotPixelSize(2),
        (width: 560, height: 840),
        reason: 'Low rendering must not lower the requested text raster size.',
      );
    },
  );

  testWidgets(
    'resolution update during an active flip defers GPU readback until settle',
    (tester) async {
      useDpr3Phone(tester);
      final controller = PageFlipController();
      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          performanceProfile: DevicePerformanceProfile.low,
          snapshotPerformanceProfile: DevicePerformanceProfile.medium,
          maxSnapshotPixelRatio: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      final asyncCapturesBefore = state.debugAsyncSnapshotCaptureCount;
      final syncCapturesBefore = state.debugSyncSnapshotCaptureCount;

      controller.nextPage();
      await tester.pump(const Duration(milliseconds: 20));
      expect(state.controller.animationController.isAnimating, isTrue);

      await tester.pumpWidget(
        buildFlip(
          controller: controller,
          performanceProfile: DevicePerformanceProfile.low,
          snapshotPerformanceProfile: DevicePerformanceProfile.medium,
          maxSnapshotPixelRatio: 1.75,
        ),
      );
      await tester.pump();

      expect(state.controller.animationController.isAnimating, isTrue);
      expect(state.debugAsyncSnapshotCaptureCount, asyncCapturesBefore);
      expect(state.debugSyncSnapshotCaptureCount, syncCapturesBefore);
      expect(state.debugDirtySnapshotIndices, isNotEmpty);

      await tester.pumpAndSettle();

      expect(
        state.debugAsyncSnapshotCaptureCount,
        greaterThan(asyncCapturesBefore),
      );
      expect(state.debugSyncSnapshotCaptureCount, syncCapturesBefore);
      expect(state.debugDirtySnapshotIndices, isEmpty);
    },
  );
}
