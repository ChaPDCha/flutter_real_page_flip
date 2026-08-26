import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';

/// A host that rebuilds while a flip is in flight must not cost the adjacent
/// pages their mounted elements.
///
/// Hosts rebuild mid-gesture for perfectly ordinary reasons — `onFlipStart`
/// itself is a callback most hosts react to (hiding a spine, a page-number
/// chrome, a scrollbar), and any inherited-widget change lands whenever it
/// lands. The engine must survive that, because the cost is not a cheap
/// repaint: `_LivePageCaptureLayer` keeps `currentIndex ± 1` mounted so it can
/// snapshot them, and it SKIPS any index whose `pageKeys` entry is missing
/// (`if (pageKey == null) continue;`). Losing those keys for even one frame
/// unmounts both neighbours; the next frame inflates them again from scratch,
/// re-shaping every `RenderParagraph` inside. In a text-heavy host (a Bible
/// reader turning a chapter) that reads as the text blinking out and back.
///
/// Uses `GlobalKey`s in `itemBuilder` exactly the way a real host does when it
/// wants its page subtrees to survive re-parenting, and asserts on ELEMENT
/// IDENTITY rather than mere presence — an element that was rebuilt has
/// already paid the re-layout cost, even though a `findsOneWidget` check would
/// still pass.
void main() {
  group('host rebuild during an in-flight flip', () {
    late Map<int, GlobalKey> pageKeys;

    setUp(() {
      pageKeys = {for (var i = 0; i < 6; i++) i: GlobalKey()};
    });

    Element? elementForPage(int index) =>
        find.byKey(pageKeys[index]!, skipOffstage: false).evaluate().isEmpty
            ? null
            : find.byKey(pageKeys[index]!, skipOffstage: false).evaluate().first;

    /// Mounts a host that can be forced to rebuild on demand, handing the
    /// engine the SAME `initialIndex` every time — the realistic case, since a
    /// host's own notion of position cannot advance until the flip lands and
    /// `onPageChanged` tells it so.
    Future<void Function()> pumpHost(
      WidgetTester tester, {
      required PageFlipController controller,
      required PageFlipSpreadMode spreadMode,
      int initialIndex = 2,
    }) async {
      late StateSetter rebuildHost;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                rebuildHost = setState;
                return PageFlipWidget(
                  controller: controller,
                  itemCount: 6,
                  initialIndex: initialIndex,
                  spreadMode: spreadMode,
                  itemBuilder: (context, index) => KeyedSubtree(
                    key: pageKeys[index],
                    child: Center(child: Text('Page $index')),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return () => rebuildHost(() {});
    }

    for (final spreadMode in PageFlipSpreadMode.values) {
      testWidgets(
        'adjacent pages keep their elements across a host rebuild '
        '(${spreadMode.name})',
        (tester) async {
          final controller = PageFlipController();
          final rebuildHost = await pumpHost(
            tester,
            controller: controller,
            spreadMode: spreadMode,
          );

          final currentBefore = elementForPage(2);
          final aheadBefore = elementForPage(3);
          final behindBefore = elementForPage(1);
          expect(
            [currentBefore, aheadBefore, behindBefore],
            everyElement(isNotNull),
            reason:
                'the capture window (current ± 1) must be mounted before the '
                'flip, or this test is not measuring what it claims',
          );

          controller.nextPage();
          // The rebuild a host performs from its own `onFlipStart` handler:
          // same frame the gesture begins, before anything has landed.
          rebuildHost();
          await tester.pump(const Duration(milliseconds: 4));

          expect(
            elementForPage(3),
            isNotNull,
            reason:
                'the page being turned INTO was unmounted by a host rebuild — '
                'it will be inflated again next frame, re-shaping all its text',
          );
          expect(
            identical(elementForPage(3), aheadBefore),
            isTrue,
            reason: 'the incoming page must keep its element across the '
                'rebuild, not be replaced by a fresh one',
          );
          expect(
            identical(elementForPage(2), currentBefore),
            isTrue,
            reason: 'the page being turned FROM must survive the rebuild too',
          );

          // And it must still be intact once the flip actually settles.
          await tester.pumpAndSettle();
          expect(identical(elementForPage(3), aheadBefore), isTrue);
        },
      );
    }

    testWidgets(
      'repeated host rebuilds throughout a flip never unmount a neighbour',
      (tester) async {
        final controller = PageFlipController();
        final rebuildHost = await pumpHost(
          tester,
          controller: controller,
          spreadMode: PageFlipSpreadMode.doubleSpread,
        );

        final aheadBefore = elementForPage(3);
        expect(aheadBefore, isNotNull);

        var unmountedFrames = 0;
        var replacements = 0;
        var previous = aheadBefore;

        controller.nextPage();
        // A host driven by an animation/notifier can rebuild on EVERY frame of
        // the gesture — the engine must be indifferent to that.
        for (var frame = 0; frame < 24; frame++) {
          rebuildHost();
          await tester.pump(const Duration(milliseconds: 4));
          final current = elementForPage(3);
          if (current == null) {
            unmountedFrames++;
            continue;
          }
          if (previous != null && !identical(current, previous)) replacements++;
          previous = current;
        }
        await tester.pumpAndSettle();

        expect(
          unmountedFrames,
          0,
          reason: 'the incoming page vanished from the tree for '
              '$unmountedFrames frame(s) mid-flip',
        );
        expect(
          replacements,
          0,
          reason: 'the incoming page was rebuilt from scratch $replacements '
              'time(s) mid-flip',
        );
      },
    );
  });
}
