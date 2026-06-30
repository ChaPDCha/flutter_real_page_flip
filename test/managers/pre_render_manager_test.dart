import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';

void main() {
  group('PreRenderManager (unit tests)', () {
    test('prepareKeys creates keys for current, prev, next', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);

      expect(mgr.pageKeys.containsKey(4), isTrue);
      expect(mgr.pageKeys.containsKey(5), isTrue);
      expect(mgr.pageKeys.containsKey(6), isTrue);
    });

    test('prepareKeys at first page only creates 0 and 1', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(0, 10);

      expect(mgr.pageKeys.containsKey(0), isTrue);
      expect(mgr.pageKeys.containsKey(1), isTrue);
      expect(mgr.pageKeys.containsKey(-1), isFalse);
    });

    test('prepareKeys at last page only creates last and second-to-last', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(9, 10);

      expect(mgr.pageKeys.containsKey(8), isTrue);
      expect(mgr.pageKeys.containsKey(9), isTrue);
      expect(mgr.pageKeys.containsKey(10), isFalse);
    });

    test('prepareKeys is idempotent', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);
      final keyCount1 = mgr.pageKeys.length;

      mgr.prepareKeys(5, 10);
      final keyCount2 = mgr.pageKeys.length;

      expect(keyCount1, equals(keyCount2));
    });

    test('cleanup removes stale keys', () {
      final mgr = PreRenderManager();

      // Prepare keys for index 5 (gets 4, 5, 6)
      mgr.prepareKeys(5, 10);

      // Also add a stale key
      mgr.pageKeys.putIfAbsent(99, GlobalKey.new);

      // Cleanup for index 5 should remove key 99 but keep 4, 5, 6
      mgr.cleanup(5, 10);

      expect(mgr.pageKeys.containsKey(99), isFalse);
      expect(mgr.pageKeys.containsKey(4), isTrue);
      expect(mgr.pageKeys.containsKey(5), isTrue);
      expect(mgr.pageKeys.containsKey(6), isTrue);
    });

    test('reset clears all keys and snapshots', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);

      expect(mgr.pageKeys.length, greaterThan(0));

      mgr.reset();

      expect(mgr.pageKeys.length, equals(0));
      expect(mgr.pageSnapshots.length, equals(0));
    });

    test('dispose cancels pending timer', () {
      final mgr = PreRenderManager();

      // dispose should not throw when no pending work
      expect(mgr.dispose, returnsNormally);
    });

    test('getCaptureIndices includes current index when includeCurrent is true',
        () {
      final mgr = PreRenderManager();

      expect(
        mgr.getCaptureIndices(5, 10, includeCurrent: true),
        equals([4, 5, 6]),
      );
    });

    test('getCaptureIndices excludes current index by default', () {
      final mgr = PreRenderManager();

      expect(mgr.getCaptureIndices(5, 10), equals([4, 6]));
    });

    test('spread capture indices include previous when warming spreads', () {
      final mgr = PreRenderManager();

      expect(
        mgr.getSpreadCaptureIndices(5, 10, includeCurrent: true),
        equals([4, 5, 6]),
      );
      expect(
        mgr.getSpreadCaptureIndices(0, 10, includeCurrent: true),
        equals([0, 1]),
      );
      expect(mgr.getSpreadCaptureIndices(5, 10), isEmpty);
    });

    test('cleanup disposes shared page and spread snapshots once', () async {
      final mgr = PreRenderManager();
      final shared = await _createTestImage();
      mgr.pageSnapshots[99] = shared;
      mgr.spreadSnapshots[99] = shared;

      expect(() => mgr.cleanup(5, 10), returnsNormally);
      expect(mgr.pageSnapshots.containsKey(99), isFalse);
      expect(mgr.spreadSnapshots.containsKey(99), isFalse);
    });

    test(
        '_doCaptureSnapshots Set-dispose prevents double dispose on shared image (regression)',
        () async {
      // Regression: captureAsSpread && index != currentIndex stores the same
      // image ref in both pageSnapshots and spreadSnapshots. When that index
      // is later evicted, the old image must be disposed exactly once (Set
      // dedup), not twice (List would crash on the second dispose).
      final mgr = PreRenderManager();
      final shared = await _createTestImage();
      // Simulate state where same image is in both maps for index 4 (a
      // non-current index captured as spread, e.g. index-1 in double-spread).
      mgr.pageSnapshots[4] = shared;
      mgr.spreadSnapshots[4] = shared;

      // cleanup for index 5 (current) — index 4 is adjacent, so it stays.
      // We need to force index 4 to be stale: cleanup for index 2 makes 4 stale.
      mgr.pageSnapshots[1] = await _createTestImage();
      mgr.pageSnapshots[3] = await _createTestImage();

      // This should not throw (the Set dedup prevents double-dispose).
      expect(() => mgr.cleanup(2, 10), returnsNormally);
      expect(mgr.pageSnapshots.containsKey(4), isFalse);
      expect(mgr.spreadSnapshots.containsKey(4), isFalse);
    });

    test('cleanup removes stale spread snapshots', () async {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);

      mgr.spreadSnapshots[5] = await _createTestImage();
      mgr.spreadSnapshots[99] = await _createTestImage();

      mgr.cleanup(5, 10);

      expect(mgr.spreadSnapshots.containsKey(5), isTrue);
      expect(mgr.spreadSnapshots.containsKey(99), isFalse);
    });
    test('hasAdjacentSnapshots returns false until snapshots exist', () {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);

      expect(
        mgr.hasAdjacentSnapshots(5, 10, includeCurrentSpread: true),
        isFalse,
      );
    });

    test('hasAdjacentSnapshots returns true when all targets are cached',
        () async {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);
      final image = await _createTestImage();

      mgr.pageSnapshots[4] = image;
      mgr.pageSnapshots[6] = image;
      mgr.spreadSnapshots[4] = image;
      mgr.spreadSnapshots[5] = image;
      mgr.spreadSnapshots[6] = image;

      expect(
        mgr.hasAdjacentSnapshots(5, 10, includeCurrentSpread: true),
        isTrue,
      );
    });

    testWidgets('retries capture on next frame when boundary is not ready', (
      tester,
    ) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);
      final previousKey = mgr.pageKeys[1];
      var captureCount = 0;

      final captureFuture = mgr.captureSnapshots(
        2,
        3,
        () => captureCount++,
        immediate: true,
      );
      await tester.pump();
      expect(mgr.hasSnapshot(1), isFalse);
      expect(mgr.isCapturePending(1), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: RepaintBoundary(
              key: previousKey,
              child: const ColoredBox(color: Color(0xFFE53935)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mgr.hasSnapshot(1), isTrue);
      expect(captureCount, greaterThan(0));
      expect(mgr.isCapturePending(1), isFalse);
      await captureFuture;
    });
  });

  // ============================================================
  // Error recovery: toImage throws, catch block, retry exhaustion
  // ============================================================
  group('error recovery', () {
    testWidgets('toImage throws, manager catches error, no crash',
        (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);
      final throwingKey = mgr.pageKeys[1];

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: _ThrowingRepaintBoundary(
              key: throwingKey,
              child: const ColoredBox(color: Color(0xFFE53935)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var captureCount = 0;
      // This should not crash despite toImage throwing
      await mgr.captureSnapshots(
        2,
        3,
        () => captureCount++,
        immediate: true,
      );

      // Pump to let retries process
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // No snapshot should be stored for the failing index
      expect(mgr.hasSnapshot(1), isFalse);
      expect(captureCount, equals(0));
      // Manager is still usable after the error
      expect(mgr.pageKeys.length, greaterThan(0));
    });

    testWidgets(
        'partial failure: working index captured despite adjacent throwing error',
        (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);

      // Build a widget tree where index 2's key wraps both boundaries,
      // and index 1's key is the inner throwing boundary.
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 100,
            child: RepaintBoundary(
              key: mgr.pageKeys[2],
              child: _ThrowingRepaintBoundary(
                key: mgr.pageKeys[1],
                child: const ColoredBox(color: Color(0xFFE53935)),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var captureCount = 0;
      await mgr.captureSnapshots(
        2,
        3,
        () => captureCount++,
        immediate: true,
        includeCurrentSpread: true,
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Index 2 is current index with includeCurrentSpread, so the image is
      // stored in spreadSnapshots (not pageSnapshots) by design.
      expect(mgr.hasSpreadSnapshot(2), isTrue);
      // Index 1 (throwing) should not be cached.
      expect(mgr.hasSnapshot(1), isFalse);
      expect(captureCount, equals(1));
    });
  });

  // ============================================================
  // Boundary indices: edge cases for capture index calculation
  // ============================================================
  group('boundary indices', () {
    test('getCaptureIndices handles negative currentIndex', () {
      final mgr = PreRenderManager();
      // Negative indices are not clamped; the method simply adds/subtracts.
      // currentIndex=-1: -1 < 9 adds index 0 (currentIndex+1). -1 > 0 is false.
      expect(mgr.getCaptureIndices(-1, 10), equals([0]));
      // currentIndex=-5: -5 < 9 adds -4 (currentIndex+1). -5 > 0 is false.
      expect(mgr.getCaptureIndices(-5, 10), equals([-4]));
    });

    test('getCaptureIndices handles currentIndex >= totalPages', () {
      final mgr = PreRenderManager();
      expect(mgr.getCaptureIndices(10, 10), equals([9]));
      expect(mgr.getCaptureIndices(15, 10), equals([14]));
    });

    test('getCaptureIndices at totalPages-1 boundary succeeds', () {
      final mgr = PreRenderManager();
      expect(mgr.getCaptureIndices(9, 10), equals([8]));
      expect(
        mgr.getCaptureIndices(9, 10, includeCurrent: true),
        equals([8, 9]),
      );
    });

    test('getCaptureIndices at index 0 boundary', () {
      final mgr = PreRenderManager();
      expect(mgr.getCaptureIndices(0, 10), equals([1]));
      expect(
        mgr.getCaptureIndices(0, 10, includeCurrent: true),
        equals([0, 1]),
      );
    });

    test('getSpreadCaptureIndices handles edge cases', () {
      final mgr = PreRenderManager();
      // Negative currentIndex: currentIndex=-1, -1 > 0 is false, so no prev.
      // includeCurrent adds -1, -1 < 9 adds 0. Returns [-1, 0].
      expect(
        mgr.getSpreadCaptureIndices(-1, 10, includeCurrent: true),
        equals([-1, 0]),
      );
      // Single page: currentIndex=0, totalPages=1. 0 > 0 false, include 0, 0 < 0 false.
      expect(
        mgr.getSpreadCaptureIndices(0, 1, includeCurrent: true),
        equals([0]),
      );
      expect(
        mgr.getSpreadCaptureIndices(0, 10, includeCurrent: true),
        equals([0, 1]),
      );
    });
  });

  // ============================================================
  // Cache hit/miss: cached indices skipped, evicted indices re-captured
  // ============================================================
  group('cache hit/miss', () {
    testWidgets('capture skips index already in pageSnapshots', (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: RepaintBoundary(
              key: mgr.pageKeys[1],
              child: const ColoredBox(color: Color(0xFFE53935)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      mgr.pageSnapshots[1] = await _createTestImage();

      var callCount = 0;
      await mgr.captureSnapshots(2, 3, () => callCount++, immediate: true);
      await tester.pump();

      expect(callCount, equals(0));
      expect(mgr.hasSnapshot(1), isTrue);
    });

    testWidgets('capture skips index already in spreadSnapshots',
        (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 100,
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: RepaintBoundary(
                    key: mgr.pageKeys[1],
                    child: const ColoredBox(color: Color(0xFFE53935)),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: RepaintBoundary(
                    key: mgr.pageKeys[2],
                    child: const ColoredBox(color: Color(0xFF4CAF50)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      mgr.spreadSnapshots[1] = await _createTestImage();

      var callCount = 0;
      await mgr.captureSnapshots(
        2,
        3,
        () => callCount++,
        immediate: true,
        includeCurrentSpread: true,
      );
      await tester.pump();
      await tester.pump();

      expect(callCount, equals(1));
      expect(mgr.spreadSnapshots.containsKey(1), isTrue);
      expect(mgr.spreadSnapshots.containsKey(2), isTrue);
    });

    testWidgets('double-spread capture can skip page snapshot clones',
        (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 4);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 100,
            child: Row(
              children: [
                for (final index in [1, 2, 3])
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: RepaintBoundary(
                      key: mgr.pageKeys[index],
                      child: ColoredBox(
                        color: Color(0xFF000000 | (index * 0x303030)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var callCount = 0;
      await mgr.captureSnapshots(
        2,
        4,
        () => callCount++,
        immediate: true,
        includeCurrentSpread: true,
        capturePageSnapshotClones: false,
      );
      await tester.pump();

      expect(callCount, equals(3));
      expect(mgr.spreadSnapshots.keys, containsAll([1, 2, 3]));
      expect(mgr.pageSnapshots, isEmpty);
      expect(
        mgr.hasAdjacentSnapshots(2, 4, includeCurrentSpread: true),
        isTrue,
      );
    });

    testWidgets('capture after cleanup eviction re-captures successfully',
        (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      mgr.prepareKeys(2, 3);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: RepaintBoundary(
              key: mgr.pageKeys[1],
              child: const ColoredBox(color: Color(0xFFE53935)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await mgr.captureSnapshots(2, 3, () {}, immediate: true);
      await tester.pump();
      await tester.pump();
      expect(mgr.hasSnapshot(1), isTrue);

      mgr.cleanup(5, 10);
      expect(mgr.hasSnapshot(1), isFalse);
      expect(mgr.pageKeys.containsKey(1), isFalse);

      mgr.prepareKeys(2, 3);
      expect(mgr.pageKeys.containsKey(1), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 100,
            height: 100,
            child: RepaintBoundary(
              key: mgr.pageKeys[1],
              child: const ColoredBox(color: Color(0xFFE53935)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var recaptureCount = 0;
      await mgr.captureSnapshots(2, 3, () => recaptureCount++, immediate: true);
      await tester.pump();
      await tester.pump();

      expect(mgr.hasSnapshot(1), isTrue);
      expect(recaptureCount, equals(1));
    });
  });

  // ============================================================
  // Memory management: flush, reset, cancel, dispose
  // ============================================================
  group('memory management', () {
    test('flushSnapshots clears all cached images', () async {
      final mgr = PreRenderManager();
      mgr.pageSnapshots[1] = await _createTestImage();
      mgr.pageSnapshots[2] = await _createTestImage();
      mgr.spreadSnapshots[3] = await _createTestImage();

      mgr.flushSnapshots();

      expect(mgr.pageSnapshots, isEmpty);
      expect(mgr.spreadSnapshots, isEmpty);
    });

    test('flushSnapshots does not throw when already empty', () {
      final mgr = PreRenderManager();
      expect(mgr.flushSnapshots, returnsNormally);
    });

    test('reset on clean manager does not throw', () {
      final mgr = PreRenderManager();
      expect(mgr.reset, returnsNormally);
    });

    test('reset after partial state does not throw', () async {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);
      mgr.pageSnapshots[4] = await _createTestImage();
      expect(mgr.reset, returnsNormally);
    });

    test('cancelPreRender when no timer does not throw', () {
      final mgr = PreRenderManager();
      expect(mgr.cancelPreRender, returnsNormally);
    });

    test('dispose is idempotent', () {
      final mgr = PreRenderManager();
      mgr.dispose();
      expect(mgr.dispose, returnsNormally);
    });

    test('dispose clears all state', () async {
      final mgr = PreRenderManager();
      mgr.prepareKeys(5, 10);
      mgr.pageSnapshots[4] = await _createTestImage();
      mgr.spreadSnapshots[5] = await _createTestImage();

      mgr.dispose();

      expect(mgr.pageSnapshots, isEmpty);
      expect(mgr.spreadSnapshots, isEmpty);
      expect(mgr.pageKeys, isEmpty);
    });
  });

  // ============================================================
  // Query methods: hasSnapshot, hasSpreadSnapshot, isCapturePending
  // ============================================================
  group('query methods', () {
    test('hasSnapshot returns true only for captured indices', () async {
      final mgr = PreRenderManager();
      mgr.pageSnapshots[3] = await _createTestImage();

      expect(mgr.hasSnapshot(3), isTrue);
      expect(mgr.hasSnapshot(0), isFalse);
      expect(mgr.hasSnapshot(-1), isFalse);
    });

    test('hasSpreadSnapshot returns true only for captured spread indices',
        () async {
      final mgr = PreRenderManager();
      mgr.spreadSnapshots[3] = await _createTestImage();

      expect(mgr.hasSpreadSnapshot(3), isTrue);
      expect(mgr.hasSpreadSnapshot(0), isFalse);
    });

    test('isCapturePending returns false for non-pending index', () {
      final mgr = PreRenderManager();
      expect(mgr.isCapturePending(5), isFalse);
    });

    test('hasAdjacentSnapshots returns false for empty manager', () {
      final mgr = PreRenderManager();
      expect(mgr.hasAdjacentSnapshots(5, 10), isFalse);
      expect(
        mgr.hasAdjacentSnapshots(5, 10, includeCurrentSpread: true),
        isFalse,
      );
    });
  });

  // ============================================================
  // refreshIndexSync: re-capture live (scrolled) content at flip start
  // ============================================================
  group('refreshIndexSync', () {
    // Reads the centre pixel [r,g,b] of an image (async GPU readback).
    Future<List<int>> centrePixel(WidgetTester tester, ui.Image image) async {
      late List<int> rgb;
      await tester.runAsync(() async {
        final data = await image.toByteData();
        final bytes = data!.buffer.asUint8List();
        final idx = ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        rgb = [bytes[idx], bytes[idx + 1], bytes[idx + 2]];
      });
      return rgb;
    }

    testWidgets('captures the CURRENT scroll position, not a stale top capture',
        (tester) async {
      const red = Color(0xFFFF0000);
      const green = Color(0xFF00FF00);
      const blue = Color(0xFF0000FF);

      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      final key = GlobalKey();
      mgr.pageKeys[0] = key;
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: RepaintBoundary(
                  key: key,
                  child: ListView(
                    controller: scrollController,
                    children: const [
                      SizedBox(height: 200, child: ColoredBox(color: red)),
                      SizedBox(height: 200, child: ColoredBox(color: green)),
                      SizedBox(height: 200, child: ColoredBox(color: blue)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Stale capture at the top of the page (red fills the viewport).
      mgr.refreshIndexSync(0);
      final topRgb = await centrePixel(tester, mgr.pageSnapshots[0]!);
      expect(topRgb[0], greaterThan(180), reason: 'top should be red. $topRgb');

      // User scrolls the second screen (green) into view, then flips.
      scrollController.jumpTo(200);
      await tester.pump();
      mgr.refreshIndexSync(0);

      final scrolledRgb = await centrePixel(tester, mgr.pageSnapshots[0]!);
      expect(
        scrolledRgb[1],
        greaterThan(180),
        reason: 'after scroll the refreshed snapshot must show green '
            '(current scroll position), not the stale red top. $scrolledRgb',
      );
      expect(scrolledRgb[0], lessThan(120));
    });

    testWidgets('no-ops safely when the index has no key', (tester) async {
      final mgr = PreRenderManager();
      addTearDown(mgr.dispose);
      // No pageKeys registered for index 0.
      expect(() => mgr.refreshIndexSync(0), returnsNormally);
      expect(mgr.pageSnapshots.containsKey(0), isFalse);
    });
  });
}

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), Paint());
  final picture = recorder.endRecording();
  return picture.toImage(10, 10);
}

class _ThrowingRenderRepaintBoundary extends RenderRepaintBoundary {
  @override
  Future<ui.Image> toImage({double pixelRatio = 1.0}) =>
      Future.error('Simulated toImage failure');
}

class _ThrowingRepaintBoundary extends RepaintBoundary {
  const _ThrowingRepaintBoundary({super.key, super.child});

  @override
  RenderRepaintBoundary createRenderObject(BuildContext context) =>
      _ThrowingRenderRepaintBoundary();
}
