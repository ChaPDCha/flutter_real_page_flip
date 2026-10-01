import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';

/// Snapshot memory safety under long, adversarial sessions.
///
/// `PreRenderManager` owns GPU-backed `ui.Image` handles and shares pixels
/// between the page and spread maps through clones. Two failure modes matter
/// in production and neither shows up in a single-scenario test:
///
/// - use-after-dispose: a handle still reachable from a map was disposed
///   (the flip painter would draw freed memory);
/// - leak: a handle removed from the maps was never disposed (GPU memory
///   grows for every page turned in a long reading session).
///
/// Seeded sessions interleave navigation, captures (including captures that
/// are still reading back while the book changes under them), synchronous
/// refreshes, invalidation, flushes, and resets. After every step every live
/// handle must be alive, no handle may be shared by two map slots, and every
/// handle that has left the maps must be disposed. At the end, every image
/// the session created must have been disposed.
void main() {
  const seeds = 12;
  const stepsPerSeed = 70;
  const total = 7;

  for (var seed = 0; seed < seeds; seed++) {
    testWidgets('snapshot handles stay valid and never leak (#$seed)',
        (tester) async {
      final random = math.Random(seed);
      final mgr = PreRenderManager();
      final created = Set<ui.Image>.identity();
      final disposed = Set<ui.Image>.identity();
      void track(ObjectEvent event) {
        final object = event.object;
        if (object is! ui.Image) return;
        if (event is ObjectCreated) created.add(object);
        if (event is ObjectDisposed) disposed.add(object);
      }

      final allocations = FlutterMemoryAllocations.instance..addListener(track);
      addTearDown(() => allocations.removeListener(track));

      final seen = Set<ui.Image>.identity();
      final log = <String>[];
      var current = random.nextInt(total);
      var shade = 0;

      Future<void> render() async {
        final entries = mgr.pageKeys.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        await tester.pumpWidget(
          MaterialApp(
            home: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in entries)
                  SizedBox(
                    width: 40,
                    height: 60,
                    child: RepaintBoundary(
                      key: entry.value,
                      child: ColoredBox(
                        color: Color(
                          0xFF000000 | ((entry.key * 37 + shade * 91) & 0xFF),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }

      Set<int> window(int index) => <int>{
            for (var i = index - 1; i <= index + 1; i++)
              if (i >= 0 && i < total) i,
          };

      void check(String where) {
        final reason = 'seed $seed, $where\n${log.join('\n')}';
        final liveList = <ui.Image>[
          ...mgr.pageSnapshots.values,
          ...mgr.spreadSnapshots.values,
        ];
        final live = Set<ui.Image>.identity()..addAll(liveList);
        expect(
          live.length,
          liveList.length,
          reason: 'one handle is shared by two map slots\n$reason',
        );
        for (final image in live) {
          expect(
            image.debugDisposed,
            isFalse,
            reason: 'a reachable snapshot was disposed\n$reason',
          );
        }
        seen.addAll(live);
        for (final image in seen) {
          if (live.contains(image)) continue;
          expect(
            image.debugDisposed,
            isTrue,
            reason: 'a snapshot left the cache without being disposed\n$reason',
          );
        }
      }

      Future<void> capture() => mgr.captureSnapshots(
            current,
            total,
            () {},
            immediate: true,
            includeCurrentSpread: random.nextBool(),
            capturePageSnapshotClones: random.nextBool(),
            pixelRatio: const <double>[0.5, 1, 2][random.nextInt(3)],
          );

      int randomWindowIndex() {
        final options = window(current).toList();
        return options[random.nextInt(options.length)];
      }

      void interfere() {
        final roll = random.nextInt(5);
        if (roll == 0) {
          mgr.refreshIndexSync(randomWindowIndex());
          log.add('  interfere: refreshIndexSync');
        } else if (roll == 1) {
          mgr.markDirty(randomWindowIndex());
          log.add('  interfere: markDirty');
        } else if (roll == 2) {
          mgr.flushSnapshots();
          log.add('  interfere: flush');
        } else if (roll == 3) {
          mgr
            ..reset()
            ..prepareKeys(current, total);
          log.add('  interfere: reset');
        } else {
          final delta = random.nextBool() ? 1 : -1;
          current = (current + delta).clamp(0, total - 1);
          mgr
            ..cleanup(current, total)
            ..prepareKeys(current, total);
          log.add('  interfere: navigate to $current');
        }
      }

      mgr.prepareKeys(current, total);
      await render();

      for (var step = 0; step < stepsPerSeed; step++) {
        final roll = random.nextDouble();
        if (roll < 0.20) {
          final jump = random.nextDouble() < 0.15;
          final delta = random.nextBool() ? 1 : -1;
          final next = jump ? random.nextInt(total) : current + delta;
          current = next.clamp(0, total - 1);
          mgr
            ..cleanup(current, total)
            ..prepareKeys(current, total);
          log.add('navigate to $current');
          final allowed = window(current);
          expect(mgr.pageKeys.keys.toSet().difference(allowed), isEmpty);
          expect(mgr.pageSnapshots.keys.toSet().difference(allowed), isEmpty);
          expect(mgr.spreadSnapshots.keys.toSet().difference(allowed), isEmpty);
          await render();
        } else if (roll < 0.45) {
          log.add('capture');
          await capture();
        } else if (roll < 0.60) {
          // A readback still in flight while the book changes under it.
          // Yielding 0-2 microtask turns lets the queued capture reach its
          // GPU readback (or not) before the interference lands.
          final yields = random.nextInt(3);
          log.add('capture + interference after $yields yields');
          final pending = capture();
          for (var i = 0; i < yields; i++) {
            await Future<void>.value();
          }
          interfere();
          check('during overlapped capture');
          await pending;
          await render();
        } else if (roll < 0.70) {
          final index = randomWindowIndex();
          log.add('refreshIndexSync $index');
          mgr.refreshIndexSync(index, pixelRatio: random.nextBool() ? 1 : 2);
        } else if (roll < 0.78) {
          log.add('markDirtyWindow');
          mgr.markDirtyWindow(current, total);
        } else if (roll < 0.86) {
          shade++;
          log.add('content change');
          await render();
        } else if (roll < 0.92) {
          log.add('flush');
          mgr.flushSnapshots();
        } else {
          log.add('reset');
          mgr
            ..reset()
            ..prepareKeys(current, total);
          await render();
        }
        await tester.pump();
        check('step $step');
      }

      mgr.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      check('after dispose');
      expect(mgr.pageSnapshots, isEmpty);
      expect(mgr.spreadSnapshots, isEmpty);
      for (final image in seen) {
        expect(image.debugDisposed, isTrue, reason: 'leaked after dispose');
      }
      final leaked = created.where((image) => !disposed.contains(image));
      expect(
        leaked,
        isEmpty,
        reason: '${leaked.length} of ${created.length} images created during '
            'the session were never disposed',
      );
    });
  }
}
