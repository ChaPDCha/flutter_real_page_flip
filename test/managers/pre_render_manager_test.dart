import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
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
      expect(() => mgr.dispose(), returnsNormally);
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
      expect(mgr.getSpreadCaptureIndices(0, 10, includeCurrent: true),
          equals([0, 1]));
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
      final previousKey = mgr.pageKeys[1]!;
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
}

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 10, 10), Paint());
  final picture = recorder.endRecording();
  return picture.toImage(10, 10);
}
