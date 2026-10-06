import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';

/// A repaint boundary whose GPU readback finishes only when the test says so.
///
/// In the test binding `toImage` completes inside `pump()`, so a capture can
/// never still be in flight when the next request arrives. On a device the
/// readback takes frames, and that is where request ordering matters.
class _SlowBoundary extends RenderRepaintBoundary {
  final List<Completer<ui.Image>> readbacks = <Completer<ui.Image>>[];

  @override
  Future<ui.Image> toImage({double pixelRatio = 1.0}) {
    final readback = Completer<ui.Image>();
    readbacks.add(readback);
    return readback.future;
  }
}

class _Slow extends SingleChildRenderObjectWidget {
  const _Slow({super.key, super.child});

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      _SlowBoundary();
}

Future<ui.Image> _image() {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 4, 4), Paint());
  return recorder.endRecording().toImage(4, 4);
}

/// Lands every readback in flight on [boundaries], in the order the manager
/// asks for them (it reads the window back one page at a time).
Future<void> _landAll(
  WidgetTester tester,
  List<_SlowBoundary> boundaries,
) async {
  for (var round = 0; round < 6; round++) {
    for (final boundary in boundaries) {
      for (final readback in boundary.readbacks) {
        if (!readback.isCompleted) {
          readback.complete((await tester.runAsync(_image))!);
        }
      }
    }
    await tester.pump();
  }
}

void main() {
  late PreRenderManager mgr;

  Future<_SlowBoundary> mountWindow(WidgetTester tester) async {
    mgr = PreRenderManager()..prepareKeys(1, 3);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (final index in <int>[0, 1, 2])
              SizedBox(
                width: 40,
                height: 60,
                child: _Slow(
                  key: mgr.pageKeys[index],
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
    return tester.renderObject<_SlowBoundary>(
      find.byKey(mgr.pageKeys[0]!),
    );
  }

  testWidgets(
      'a debounced request does not throw away a readback already in flight',
      (tester) async {
    final first = await mountWindow(tester);

    // A shape jump asks for an immediate recapture; its first readback starts.
    unawaited(
      mgr.captureSnapshots(
        1,
        3,
        () {},
        immediate: true,
        includeCurrentSpread: true,
      ),
    );
    await tester.pump();
    expect(first.readbacks, hasLength(1));

    // A frame later a small follow-up resize marks the window stale and asks
    // for the debounced path (what PageFlipWidget._handleSizeChange does).
    mgr.markDirtyWindow(1, 3);
    unawaited(
      mgr.captureSnapshots(1, 3, () {}, includeCurrentSpread: true),
    );

    // The readback for the new shape lands after that request.
    final landed = (await tester.runAsync(_image))!;
    first.readbacks.first.complete(landed);
    await tester.pump();

    expect(
      landed.debugDisposed,
      isFalse,
      reason: 'That readback is the new shape; discarding it brings back the '
          'old, stretched snapshot until the debounce fires',
    );
    expect(identical(mgr.spreadSnapshots[0], landed), isTrue);
    mgr.dispose();
  });

  testWidgets('the debounced request still refreshes once its delay is over',
      (tester) async {
    final first = await mountWindow(tester);
    final all = <_SlowBoundary>[
      for (final index in <int>[0, 1, 2])
        tester.renderObject<_SlowBoundary>(find.byKey(mgr.pageKeys[index]!)),
    ];
    unawaited(
      mgr.captureSnapshots(
        1,
        3,
        () {},
        immediate: true,
        includeCurrentSpread: true,
      ),
    );
    await tester.pump();
    mgr.markDirtyWindow(1, 3);
    unawaited(
      mgr.captureSnapshots(1, 3, () {}, includeCurrentSpread: true),
    );
    // The whole window of the in-flight recapture lands, page by page. Only
    // the page read back before the follow-up change is still stale.
    await _landAll(tester, all);
    expect(mgr.dirtyIndices, <int>{0});
    final readbacksBefore = first.readbacks.length;

    await tester.pump(const Duration(milliseconds: 290));
    expect(first.readbacks.length, readbacksBefore, reason: 'still debounced');
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      first.readbacks.length,
      greaterThan(readbacksBefore),
      reason: 'The small follow-up change is captured after the debounce',
    );
    mgr.dispose();
  });

  testWidgets('an immediate request still supersedes an older readback',
      (tester) async {
    final first = await mountWindow(tester);
    unawaited(
      mgr.captureSnapshots(
        1,
        3,
        () {},
        immediate: true,
        includeCurrentSpread: true,
      ),
    );
    await tester.pump();

    // A newer immediate request (another jump) makes the in-flight one stale.
    unawaited(
      mgr.captureSnapshots(
        1,
        3,
        () {},
        immediate: true,
        includeCurrentSpread: true,
      ),
    );
    final stale = (await tester.runAsync(_image))!;
    first.readbacks.first.complete(stale);
    await tester.pump();

    expect(mgr.spreadSnapshots[0], isNot(same(stale)));
    expect(
      stale.debugDisposed,
      isTrue,
      reason: 'A superseded readback is disposed, not leaked',
    );
    mgr.dispose();
  });
}
