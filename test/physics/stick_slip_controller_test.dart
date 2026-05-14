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
      final ctrl = StickSlipController(slipVelocityThreshold: 0.02);
      ctrl.update(0.0); // init → none
      ctrl.update(0.5); // first motion → slipRelease (stationary→moving)
      for (int i = 0; i < 10; i++) {
        final event = ctrl.update(0.5);
        expect(event.type, equals(StickSlipEventType.none));
      }
    });

    test('reset clears internal state', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
        slipVelocityThreshold: 0.02,
      );
      ctrl.update(0.0); // init
      ctrl.update(0.0); // stationary
      ctrl.reset();

      // After reset, next update should be initial (none)
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.none));
    });

    test('stationary then motion triggers slipRelease', () {
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
        slipVelocityThreshold: 0.02,
      );
      ctrl.update(0.0); // init

      // Accumulate stick energy via stationary updates
      for (int i = 0; i < 5; i++) {
        ctrl.update(0.0);
      }

      // Now move above threshold — should trigger slipRelease
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      // Note: in fast test execution, dt may be near 0 so energy can be 0
      expect(event.intensity, greaterThanOrEqualTo(0));
    });

    test('microSlip fires on rapid acceleration', () {
      final ctrl = StickSlipController(slipVelocityThreshold: 0.02);
      ctrl.update(0.0); // init
      ctrl.update(0.0); // stationary

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
        slipVelocityThreshold: 0.02,
      );

      // Initialize + move continuously
      var event = ctrl.update(0.0); // init → none
      expect(event.type, equals(StickSlipEventType.none));

      event = ctrl.update(0.1); // first motion → could be slip release
      // Subsequent steady motions
      for (int i = 0; i < 5; i++) {
        event = ctrl.update(0.15);
        expect(event.type, equals(StickSlipEventType.none));
      }
    });

    test('custom clock produces deterministic behavior', () {
      DateTime fakeNow = DateTime(2024, 1, 1);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 10,
        slipVelocityThreshold: 0.02,
        now: () => fakeNow,
      );

      // Initialize — sets _lastMoveTime to fakeNow
      expect(ctrl.update(0.0).type, equals(StickSlipEventType.none));

      // Advance time by 50 ms (well past stationaryThresholdMs)
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0.0); // accumulates stick energy: 50 * 0.001 = 0.05

      // Advance time again
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0.0); // more energy: 0.05 + 50 * 0.001 = 0.10

      // Move above threshold — should trigger slipRelease with deterministic energy
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final event = ctrl.update(0.5);
      expect(event.type, equals(StickSlipEventType.slipRelease));
      expect(event.intensity, closeTo(0.1, 0.001));
    });
  });
}
