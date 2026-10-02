import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/page_flip_layer_view.dart';

/// Stage-2 snapshot lifecycle coverage:
/// - structural changes never restructure under a page in the air,
/// - count-only appends keep snapshots (no reset),
/// - resize / DPR changes mark stale instead of flushing,
/// - instant (skip-animation) taps do no synchronous capture,
/// - OffscreenPreRenderer keeps its subtree across state toggles.
void main() {
  Widget buildFlip({
    int itemCount = 8,
    int initialIndex = 2,
    Size size = const Size(320, 480),
    PageFlipController? controller,
    bool skipTapAnimation = false,
    ValueChanged<int>? onPageChanged,
    VoidCallback? onFlipStart,
  }) =>
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: PageFlipWidget(
              key: const ValueKey<String>('stable-flip'),
              controller: controller,
              itemCount: itemCount,
              initialIndex: initialIndex,
              onPageChanged: onPageChanged,
              onFlipStart: onFlipStart,
              config: PageFlipConfig(
                duration: const Duration(milliseconds: 120),
                enableHaptics: false,
                enableSound: false,
                skipTapAnimation: skipTapAnimation,
              ),
              itemBuilder: (context, index) => ColoredBox(
                color: Color(0xFF000000 | (index * 0x101010)),
                child: Text('page $index'),
              ),
            ),
          ),
        ),
      );

  PageFlipWidgetState stateOf(WidgetTester tester) =>
      tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));

  testWidgets('appending pages while idle keeps snapshots (no reset)',
      (tester) async {
    await tester.pumpWidget(buildFlip());
    await tester.pumpAndSettle();
    final state = stateOf(tester);
    expect(state.debugSnapshotPixelSize(3), isNotNull);

    await tester.pumpWidget(buildFlip(itemCount: 12));
    await tester.pump();

    expect(stateOf(tester), same(state));
    expect(state.controller.currentIndex, 2);
    expect(
      state.debugSnapshotPixelSize(3),
      isNotNull,
      reason: 'An append that leaves the current page in place must not '
          'flush the capture window',
    );

    await tester.pumpAndSettle();
    expect(state.debugDirtySnapshotIndices, isEmpty);
  });

  testWidgets('shrinking past the current page clamps and resets',
      (tester) async {
    final controller = PageFlipController();
    await tester.pumpWidget(buildFlip(controller: controller));
    await tester.pumpAndSettle();
    await controller.goToPage(6);
    await tester.pumpAndSettle();

    // initialIndex stays 2 (unchanged), so this is a pure count change that
    // forces a clamp from 6 to the new last page.
    await tester.pumpWidget(buildFlip(controller: controller, itemCount: 4));
    await tester.pumpAndSettle();

    expect(stateOf(tester).controller.currentIndex, 3);
    expect(find.text('page 3'), findsWidgets);
  });

  testWidgets('an external jump during an animated flip waits for the turn',
      (tester) async {
    final controller = PageFlipController();
    final changes = <int>[];
    await tester.pumpWidget(
      buildFlip(controller: controller, onPageChanged: changes.add),
    );
    await tester.pumpAndSettle();
    final state = stateOf(tester);

    controller.nextPage();
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.controller.isDragging, isTrue);

    await tester.pumpWidget(
      buildFlip(
        controller: controller,
        initialIndex: 5,
        onPageChanged: changes.add,
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      state.controller.currentIndex,
      2,
      reason: 'The index must not move while the page is in the air',
    );
    expect(state.debugSnapshotPixelSize(3), isNotNull);

    await tester.pumpAndSettle();
    expect(changes, <int>[3], reason: 'The in-flight turn still commits');
    expect(state.controller.currentIndex, 5);
  });

  testWidgets('resizing keeps stale snapshots until they are replaced',
      (tester) async {
    await tester.pumpWidget(buildFlip());
    await tester.pumpAndSettle();
    final state = stateOf(tester);
    final before = state.debugSnapshotPixelSize(3);
    expect(before, isNotNull);

    // A small step (5% wider): the shape barely changes, so the replacement
    // waits out the debounce meant for continuous resizes. A change of shape
    // (fold, unfold, rotation) is replaced at once instead; that path is
    // covered by page_flip_foldable_test.dart.
    await tester.pumpWidget(buildFlip(size: const Size(336, 480)));
    await tester.pump();
    await tester.pump();

    expect(
      state.debugSnapshotPixelSize(3),
      before,
      reason: 'Resize must not flush images a flip may still be painting',
    );
    expect(state.debugDirtySnapshotIndices, contains(3));

    // Debounced refresh (300 ms), then the async readback.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(state.debugDirtySnapshotIndices, isEmpty);
    expect(state.debugSnapshotPixelSize(3)!.width, greaterThan(before!.width));
  });

  testWidgets('a device pixel ratio change recaptures the window',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(buildFlip());
    await tester.pumpAndSettle();
    final state = stateOf(tester);
    expect(state.debugSnapshotPixelSize(3)!.width, 320);

    tester.view.devicePixelRatio = 2;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugSnapshotPixelSize(3)!.width, 640);
    expect(state.debugDirtySnapshotIndices, isEmpty);
  });

  testWidgets(
      'a refresh that cannot wait is not downgraded by one already queued',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(buildFlip());
    await tester.pumpAndSettle();
    final state = stateOf(tester);
    expect(state.debugSnapshotPixelSize(3)!.width, 320);

    // Frame N: a small step (2.5% wider) queues a debounced refresh. Its
    // post-frame callback is still pending when the next frame starts.
    await tester.pumpWidget(buildFlip(size: const Size(328, 480)));
    // Frame N+1: the pixel ratio doubles while that callback is pending. The
    // new refresh cannot wait for the debounce, and must not be folded into
    // the queued one.
    tester.view.devicePixelRatio = 2;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      state.debugSnapshotPixelSize(3)!.width,
      656,
      reason: 'The window is recaptured at the new pixel ratio within a few '
          'frames, not after the 300 ms debounce',
    );
    expect(state.debugDirtySnapshotIndices, isEmpty);
  });

  testWidgets('instant tap navigation performs no synchronous capture',
      (tester) async {
    final controller = PageFlipController();
    var flipStarts = 0;
    await tester.pumpWidget(
      buildFlip(
        controller: controller,
        skipTapAnimation: true,
        onFlipStart: () => flipStarts++,
      ),
    );
    await tester.pumpAndSettle();
    final state = stateOf(tester);
    final syncBefore = state.debugSyncSnapshotCaptureCount;

    controller.nextPage();
    await tester.pumpAndSettle();

    expect(state.controller.currentIndex, 3);
    expect(flipStarts, 1, reason: 'The host lifecycle callback still fires');
    expect(
      state.debugSyncSnapshotCaptureCount,
      syncBefore,
      reason: 'No frame of an instant turn is drawn, so no sync readback',
    );
  });

  testWidgets('OffscreenPreRenderer keeps its subtree across toggles',
      (tester) async {
    Widget host({required bool offscreen}) => MaterialApp(
          home: OffscreenPreRenderer(
            isOffscreen: offscreen,
            child: const _Probe(),
          ),
        );

    await tester.pumpWidget(host(offscreen: false));
    final probe = tester.state(find.byType(_Probe));

    await tester.pumpWidget(host(offscreen: true));
    expect(tester.state(find.byType(_Probe)), same(probe));

    await tester.pumpWidget(host(offscreen: false));
    expect(tester.state(find.byType(_Probe)), same(probe));
  });
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
