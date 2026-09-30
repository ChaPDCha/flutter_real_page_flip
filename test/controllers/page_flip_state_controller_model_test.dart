import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';

/// Model-based test of [PageFlipStateController].
///
/// Seeded random event streams (fingers, taps, time, settings changes,
/// external aborts) are fed to a real controller exactly the way
/// `PageFlipGestureLayer` feeds it, and after EVERY step the controller must
/// satisfy the engine's invariants:
///
/// 1. `currentIndex` stays inside the book.
/// 2. `dragProgress` is finite and inside `[0, 1]`.
/// 3. Lifecycle balance: `onFlipStart - onFlipEnd == (isBusy ? 1 : 0)`.
/// 4. Idle means reset: not busy => progress 0.
/// 5. No finger down => content hit-testing is not blocked.
/// 6. A settle only moves toward its decided target (never restarts/jumps).
/// 7. The outcome decided at release is the outcome that happens, and a
///    commit moves exactly one page in the turn's direction.
/// 8. Sound and settle haptics are never emitted for more turns than
///    actually committed, except for turns aborted after emitting them.
///
/// Every past gesture/state bug in this engine (reverse flick committing,
/// a touch re-deciding a settle, tap flips racing a held finger) violates at
/// least one of these, so this suite is the regression net for the whole
/// class rather than for one reproduction.
void main() {
  const seeds = 40;
  const stepsPerSeed = 220;

  for (var seed = 0; seed < seeds; seed++) {
    testWidgets('random session #$seed keeps every invariant', (tester) async {
      final model = _Model(math.Random(seed), total: 2 + seed % 6);
      addTearDown(model.controller.dispose);

      for (var step = 0; step < stepsPerSeed; step++) {
        await model.randomStep(tester);
        model.checkInvariants('seed $seed, step $step');
      }

      // Finish: lift any finger, let every animation and finalize run.
      model.release(velocity: 0);
      await tester.pumpAndSettle();
      model.checkInvariants('seed $seed, final');
      expect(model.controller.isBusy, isFalse, reason: model.trace);
      expect(model.controller.dragProgress, 0, reason: model.trace);
      expect(model.controller.blocksContentPointers, isFalse);
      expect(model.starts, model.ends, reason: model.trace);
    });
  }
}

/// Outcome the controller committed to when a turn was released or started.
class _Expectation {
  _Expectation({required this.commit, required this.from, required this.to});

  final bool commit;
  final int from;
  final int to;
}

class _Model {
  _Model(this.random, {required this.total}) {
    controller = PageFlipStateController(
      vsync: const TestVSync(),
      animationDuration: const Duration(milliseconds: 300),
      onUpdate: () {},
      onPageFinalized: (index) {
        finalized.add(index);
        expectSync(index, controller.currentIndex, reason: trace);
      },
      onFlipStart: () => starts++,
      onFlipEnd: () => ends++,
      onEffectTrigger: (
        effect, {
        intensity,
        volume,
        texture,
        resistance,
      }) {
        if (effect == PageFlipEvent.sound) sounds++;
        if (effect == PageFlipEvent.impulseHaptic) impulses++;
        if (volume != null) {
          expectSync(volume.isFinite && volume >= 0 && volume <= 1, isTrue);
        }
        if (intensity != null) expectSync(intensity, greaterThanOrEqualTo(0));
      },
    )
      ..updateCachedWidth(400)
      ..updateCachedHeight(600)
      ..setIndex(random.nextInt(total), total);
  }

  final math.Random random;
  final int total;
  late final PageFlipStateController controller;

  final List<int> finalized = <int>[];
  int starts = 0;
  int ends = 0;
  int sounds = 0;
  int impulses = 0;
  int effectiveAborts = 0;

  // Finger model, mirroring PageFlipGestureLayer.
  bool pointerDown = false;
  bool pointerAccepted = false; // onDragStart returned true
  bool pointerRefused = false; // settle in progress when intent was detected
  double touchY = 300;

  _Expectation? expectation;
  double? lastSettleProgress;
  int finalizedBefore = 0;
  int indexBefore = 0;

  final List<String> _log = <String>[];
  String get trace => _log.skip(math.max(0, _log.length - 25)).join('\n');

  void _record(String event) => _log.add(
        '$event -> idx=${controller.currentIndex} '
        'p=${controller.dragProgress.toStringAsFixed(3)} '
        'drag=${controller.isDragging} gest=${controller.isGestureActive} '
        'settle=${controller.isSettling}',
      );

  Future<void> randomStep(WidgetTester tester) async {
    finalizedBefore = finalized.length;
    indexBefore = controller.currentIndex;
    final roll = random.nextDouble();

    if (!pointerDown) {
      if (roll < 0.35) {
        pointerDown = true;
        pointerAccepted = false;
        pointerRefused = false;
        touchY = random.nextDouble() * 600;
        _record('down');
      } else if (roll < 0.50) {
        tap(isNext: random.nextBool());
      } else if (roll < 0.88) {
        await pump(tester);
      } else if (roll < 0.94) {
        updateSettings();
      } else {
        abort();
      }
      return;
    }

    if (!pointerAccepted && !pointerRefused) {
      if (roll < 0.70) {
        accept();
      } else if (roll < 0.85) {
        release(velocity: 0);
      } else {
        await pump(tester);
      }
      return;
    }

    if (roll < 0.45) {
      move();
    } else if (roll < 0.60) {
      release(velocity: (random.nextDouble() * 2 - 1) * 2500);
    } else if (roll < 0.65) {
      cancel();
    } else if (roll < 0.77) {
      await pump(tester, maxMs: 50);
    } else if (roll < 0.87) {
      tap(isNext: random.nextBool());
    } else if (roll < 0.92) {
      abort();
    } else {
      updateSettings();
    }
  }

  void accept() {
    // Touch slop is at least ~1 px and at most 18 px; credit 10..60 px.
    final magnitude = 10 + random.nextDouble() * 50;
    final dx = random.nextBool() ? -magnitude : magnitude;
    if (controller.isSettling) {
      pointerRefused = true;
      _record('accept refused (settling)');
      return;
    }
    controller.beginPointerCapture();
    final accepted = controller.onDragStart(
      DragStartDetails(localPosition: Offset(200, touchY)),
      total,
      accumulatedTotalDx: dx,
    );
    if (!accepted) {
      controller.endPointerCapture();
      pointerRefused = true;
    } else {
      pointerAccepted = true;
    }
    _record('accept dx=${dx.toStringAsFixed(1)} accepted=$accepted');
  }

  void move() {
    if (!pointerAccepted) return;
    final dx = (random.nextDouble() * 2 - 1) * 60;
    final vertical = random.nextDouble() >= 0.7;
    final dy = vertical ? (random.nextDouble() - 0.5) * 30 : 0.0;
    touchY += dy;
    controller.onDragUpdate(
      DragUpdateDetails(
        delta: Offset(dx, dy),
        primaryDelta: dy == 0 ? dx : null,
        globalPosition: Offset(200, touchY),
        localPosition: Offset(200, touchY),
      ),
      total,
    );
    _record('move dx=${dx.toStringAsFixed(1)} dy=${dy.toStringAsFixed(1)}');
  }

  void release({required double velocity}) {
    if (!pointerDown) return;
    if (pointerAccepted) {
      final c = controller;
      if (c.isDragging && !c.isSettling) {
        final from = c.currentIndex;
        final forward = c.isForward;
        final threshold = forward ? c.cutoffForward : c.cutoffPrevious;
        final commit = shouldCommitFlip(
          isForward: forward,
          progress: c.dragProgress,
          releaseVelocityPxPerSecond: velocity,
          threshold: threshold,
        );
        expectation = _Expectation(
          commit: commit,
          from: from,
          to: forward ? from + 1 : from - 1,
        );
      }
      controller.onDragEnd(
        DragEndDetails(
          primaryVelocity: velocity,
          velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
        ),
        total,
      );
      controller.endPointerCapture();
    }
    _resetPointer();
    _record('up v=${velocity.toStringAsFixed(0)}');
  }

  void cancel() {
    if (!pointerDown) return;
    if (pointerAccepted) {
      if (controller.isDragging && !controller.isSettling) {
        final from = controller.currentIndex;
        expectation = _Expectation(commit: false, from: from, to: from);
      }
      controller.onDragCancel(total);
      controller.endPointerCapture();
    }
    _resetPointer();
    _record('cancel');
  }

  void _resetPointer() {
    pointerDown = false;
    pointerAccepted = false;
    pointerRefused = false;
  }

  void tap({required bool isNext}) {
    final startsBefore = starts;
    final from = controller.currentIndex;
    final busy = controller.isBusy;
    controller.triggerTapFlip(isNext: isNext, totalPages: total);
    final accepted = starts > startsBefore;
    final atBoundary = isNext ? from >= total - 1 : from <= 0;
    expect(
      accepted,
      !busy && !atBoundary,
      reason: 'tap accepted iff idle and not at a boundary\n$trace',
    );
    if (accepted) {
      final to = isNext ? from + 1 : from - 1;
      expectation = _Expectation(commit: true, from: from, to: to);
    }
    _record('tap next=$isNext accepted=$accepted');
  }

  void abort() {
    final wasBusy = controller.isBusy;
    controller.cancelActiveFlip();
    if (wasBusy) {
      effectiveAborts++;
      final from = controller.currentIndex;
      expectation = _Expectation(commit: false, from: from, to: from);
    }
    _record('abort busy=$wasBusy');
  }

  void updateSettings() {
    controller.updateSettings(
      animationDuration: Duration(milliseconds: 40 + random.nextInt(560)),
      cutoffForward: 0.1 + random.nextDouble() * 0.8,
      cutoffPrevious: 0.1 + random.nextDouble() * 0.8,
    );
    _record('settings');
  }

  Future<void> pump(WidgetTester tester, {int maxMs = 400}) async {
    const choices = <int>[0, 8, 16, 33, 50, 120, 400];
    final ms = choices.where((c) => c <= maxMs).toList();
    final duration = ms[random.nextInt(ms.length)];
    await tester.pump(Duration(milliseconds: duration));
    _record('pump ${duration}ms');
  }

  void checkInvariants(String where) {
    final c = controller;
    final reason = '$where\n$trace';

    // 1. Index inside the book.
    expect(c.currentIndex, inInclusiveRange(0, total - 1), reason: reason);

    // 2. Progress finite and normalised.
    expect(c.dragProgress.isFinite, isTrue, reason: reason);
    expect(c.dragProgress, inInclusiveRange(0.0, 1.0), reason: reason);

    // 3. Every start is matched by exactly one end once the page is free.
    expect(starts - ends, c.isBusy ? 1 : 0, reason: reason);

    // 4. Idle means fully reset.
    if (!c.isBusy) {
      expect(c.dragProgress, 0, reason: reason);
      expect(c.isDragging, isFalse, reason: reason);
    }

    // 5. Content is never left blocked without a finger on the page.
    if (!pointerDown) {
      expect(c.blocksContentPointers, isFalse, reason: reason);
    }

    // 6. A settle moves monotonically toward its decided target.
    final exp = expectation;
    if (c.isSettling && exp != null) {
      final previous = lastSettleProgress;
      if (previous != null) {
        if (exp.commit) {
          expect(
            c.dragProgress,
            greaterThanOrEqualTo(previous - 1e-9),
            reason: 'committed settle moved backward\n$reason',
          );
        } else {
          expect(
            c.dragProgress,
            lessThanOrEqualTo(previous + 1e-9),
            reason: 'snap-back moved forward\n$reason',
          );
        }
      }
      lastSettleProgress = c.dragProgress;
    } else {
      lastSettleProgress = null;
    }

    // 7. A page change is one step, and only as decided.
    final newChanges = finalized.length - finalizedBefore;
    expect(newChanges, inInclusiveRange(0, 1), reason: reason);
    if (newChanges == 1) {
      expect((c.currentIndex - indexBefore).abs(), 1, reason: reason);
    }
    if (exp != null && !c.isBusy) {
      if (exp.commit) {
        expect(c.currentIndex, exp.to, reason: 'commit lost\n$reason');
        expect(finalized, isNotEmpty, reason: reason);
        expect(finalized.last, exp.to, reason: reason);
      } else {
        expect(c.currentIndex, exp.from, reason: 'cancel committed\n$reason');
      }
      expectation = null;
    }

    // 8. Turn-end feedback never outnumbers committed turns, except for the
    //    turn still in flight and turns aborted after emitting it.
    final slack = effectiveAborts + (c.isBusy ? 1 : 0);
    expect(
      sounds - finalized.length,
      inInclusiveRange(0, slack),
      reason: reason,
    );
    expect(
      impulses - finalized.length,
      inInclusiveRange(0, slack),
      reason: reason,
    );
  }
}
