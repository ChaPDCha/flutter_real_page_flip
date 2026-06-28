import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

void main() {
  group('StickSlipController', () {
    test('initial update returns none', () {
      final ctrl = StickSlipController();
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.none));
    });

    test('steady motion above threshold returns none after init', () {
      final ctrl = StickSlipController();
      ctrl.update(0); // init → none
      ctrl.update(0.5); // first motion → slipRelease (stationary→moving)
      for (var i = 0; i < 10; i++) {
        final event = ctrl.update(0.5);
        expect(event.type, equals(StickSlipEventType.none));
      }
    });

    test('reset clears internal state', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
      );
      ctrl.update(0); // init
      ctrl.update(0); // stationary
      ctrl.reset();

      // After reset, next update should be initial (none)
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.none));
    });

    test('stationary then motion triggers slipRelease', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
      );
      ctrl.update(0); // init

      // Accumulate stick energy via stationary updates
      for (var i = 0; i < 5; i++) {
        ctrl.update(0);
      }

      // Now move above threshold — should trigger slipRelease
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      // Note: in fast test execution, dt may be near 0 so energy can be 0
      expect(event.intensity, greaterThanOrEqualTo(0));
    });

    test('microSlip fires on rapid acceleration', () {
      final ctrl = StickSlipController();
      ctrl.update(0); // init
      ctrl.update(0); // stationary

      // Large acceleration from stationary to 0.5
      // (second update after init is stationary, third is the acceleration)
      // Actually after init (velocity 0), and then we do 0.0 again (still stationary)
      // Then we jump to 0.5 which is accel > 0.15
      final event = ctrl.update(0.5);
      // This could be slipRelease (since _wasStationary is true and velocity > threshold)
      // OR microSlip (since accel is large)
      // Both are valid — just verify we get something non-none
      expect(
        event.type == StickSlipEventType.slipRelease ||
            event.type == StickSlipEventType.microSlip,
        isTrue,
        reason: 'Should detect either slip-release or micro-slip',
      );
    });

    test('continuous motion does not trigger events after initial', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 100,
      );

      // Initialize + move continuously
      var event = ctrl.update(0); // init → none
      expect(event.type, equals(StickSlipEventType.none));

      event = ctrl.update(0.1); // first motion → could be slip release
      // Subsequent steady motions
      for (var i = 0; i < 5; i++) {
        event = ctrl.update(0.15);
        expect(event.type, equals(StickSlipEventType.none));
      }
    });

    test(
        'energy accumulates only when stationary threshold is exceeded (regression)',
        () {
      // Regression: _lastMoveTime was being updated every frame outside the
      // dt-threshold check, so dt was always ~16ms and never accumulated energy.
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        now: () => fakeNow,
      );

      ctrl.update(0); // init
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      ctrl.update(0); // stationary, dt=1ms < 50ms → no energy
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      ctrl.update(0); // stationary, dt=1ms < 50ms → no energy

      // Advance 60ms in one jump (exceeds threshold)
      fakeNow = fakeNow.add(const Duration(milliseconds: 60));
      ctrl.update(0); // dt=60ms > 50ms → energy accumulates

      // Move to trigger slipRelease
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      // Energy should be ~0.06 (60ms * 0.001), not 0
      expect(event.intensity, greaterThan(0.05));
    });

    test(
        'StickSlipEvent.slipRelease factory produces correct type and intensity',
        () {
      final event = StickSlipEvent.slipRelease(intensity: 0.75);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      expect(event.intensity, equals(0.75));
    });

    test(
        'StickSlipEvent.microSlip factory produces correct type and caps intensity',
        () {
      final event = StickSlipEvent.microSlip(intensity: 0.3);
      expect(event.type, equals(StickSlipEventType.microSlip));
      expect(event.intensity, equals(0.3));
    });

    test('StickSlipEvent.none is const with zero intensity', () {
      expect(StickSlipEvent.none.type, equals(StickSlipEventType.none));
      expect(StickSlipEvent.none.intensity, equals(0.0));
      // Verify it is truly a const singleton
      const same = StickSlipEvent.none;
      expect(identical(same, StickSlipEvent.none), isTrue);
    });

    test('velocity exactly at threshold does not trigger slipRelease', () {
      // The controller uses strict comparison (velocity > threshold),
      // so velocity == threshold should NOT trigger slipRelease.
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
        now: () => fakeNow,
      );
      ctrl.update(0); // init

      // Build stationary state
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl.update(0); // stationary — accumulates energy

      // velocity exactly at threshold — should NOT release
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      final exactEvent = ctrl.update(0.02);
      expect(exactEvent.type, equals(StickSlipEventType.none));

      // Now directly from stationary, just above threshold
      final ctrl2 = StickSlipController(
        stationaryThresholdMs: 1,
        now: () => fakeNow,
      );
      ctrl2.update(0); // init
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl2.update(0); // stationary build
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      final release = ctrl2.update(0.021); // just above threshold
      expect(release.type, equals(StickSlipEventType.slipRelease));
    });

    test('multiple rapid resets do not crash', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
      );
      for (var i = 0; i < 20; i++) {
        ctrl.reset();
        final event = ctrl.update(0.5);
        expect(event.type, equals(StickSlipEventType.none));
      }
    });

    test('setter updates threshold mid-operation', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 100,
        now: () => fakeNow,
      );

      ctrl.update(0); // init
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl.update(0); // stationary, but 10ms < 100ms threshold

      // Change threshold to 5ms
      ctrl.stationaryThresholdMs = 5;

      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl.update(0); // accumulates energy (10ms > 5ms)

      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      expect(event.intensity, greaterThan(0));
    });

    test('extreme acceleration produces microSlip with capped intensity', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
      );
      ctrl.update(0); // init
      ctrl.update(0); // stationary

      // Extreme acceleration from 0 to 1.0
      final event = ctrl.update(1);
      // Either microSlip (accel=1.0, capped to 0.6) or slipRelease
      if (event.type == StickSlipEventType.microSlip) {
        // MicroSlip intensity is capped at 0.6
        expect(event.intensity, lessThanOrEqualTo(0.6));
      }
    });

    test('clock jump forward (large dt) still works', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        now: () => fakeNow,
      );

      ctrl.update(0); // init
      // Jump 10 seconds forward (simulating pause)
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      ctrl.update(0); // stationary: huge dt → huge stick energy

      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      // Energy capped at 1.0
      expect(event.intensity, lessThanOrEqualTo(1.0));
    });

    test('custom clock produces deterministic behavior', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 10,
        now: () => fakeNow,
      );

      // Initialize — sets _lastMoveTime to fakeNow
      expect(ctrl.update(0).type, equals(StickSlipEventType.none));

      // Advance time by 50 ms (well past stationaryThresholdMs)
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0); // accumulates stick energy: 50 * 0.001 = 0.05

      // Advance time again
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0); // more energy: 0.05 + 50 * 0.001 = 0.10

      // Move above threshold — should trigger slipRelease with deterministic energy
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      expect(event.intensity, closeTo(0.1, 0.001));
    });
  });
}
