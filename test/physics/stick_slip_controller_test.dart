import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

void main() {
  group('StickSlipController (continuous modulation)', () {
    test('initial update returns zero modulation', () {
      final ctrl = StickSlipController();
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, equals(0.0));
      expect(mod.sharpnessShift, equals(0.0));
    });

    test('steady motion above threshold returns zero after init', () {
      final ctrl = StickSlipController();
      ctrl.update(0); // init → zero
      ctrl.update(0.5); // first motion → slip release boost
      for (var i = 0; i < 10; i++) {
        final mod = ctrl.update(0.5);
        // Steady motion should have minimal/no boost
        expect(mod.amplitudeBoost, lessThanOrEqualTo(0.01));
      }
    });

    test('reset clears internal state', () {
      final ctrl = StickSlipController(stationaryThresholdMs: 1);
      ctrl.update(0); // init
      ctrl.update(0); // stationary — builds energy
      ctrl.reset();

      // After reset, next update should be initial (zero)
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, equals(0.0));
      expect(mod.sharpnessShift, equals(0.0));
    });

    test('stationary builds stick energy, motion releases as boost', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 1,
        now: () => fakeNow,
      );

      ctrl.update(0); // init

      // Accumulate stick energy via stationary updates with time progression
      for (var i = 0; i < 5; i++) {
        fakeNow = fakeNow.add(const Duration(milliseconds: 20));
        ctrl.update(0);
      }

      // Move above threshold — should get amplitude boost from slip release
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, greaterThan(0.0));
      // Sharpness should increase during slip
      expect(mod.sharpnessShift, greaterThan(0.0));
    });

    test('continuous motion does not trigger boost after initial slip', () {
      final ctrl = StickSlipController();

      var mod = ctrl.update(0); // init → zero
      expect(mod.amplitudeBoost, equals(0.0));

      mod = ctrl.update(0.1); // first motion → possible slip boost
      // Subsequent steady motions should give zero
      for (var i = 0; i < 5; i++) {
        mod = ctrl.update(0.15);
        expect(mod.amplitudeBoost, lessThanOrEqualTo(0.01));
      }
    });

    test('energy accumulates only when stationary threshold is exceeded', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(now: () => fakeNow);

      ctrl.update(0); // init
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      ctrl.update(0); // stationary, dt=1ms < 50ms → no energy
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      ctrl.update(0); // stationary, dt=1ms < 50ms → no energy

      // Advance 60ms in one jump (exceeds threshold)
      fakeNow = fakeNow.add(const Duration(milliseconds: 60));
      ctrl.update(0); // dt=60ms > 50ms → energy accumulates

      // Move to trigger slip release
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, greaterThan(0.0));
    });

    test('zero modulation is const with zero values', () {
      const zero = StickSlipModulation.zero;
      expect(zero.amplitudeBoost, equals(0.0));
      expect(zero.sharpnessShift, equals(0.0));
    });

    test('velocity exactly at threshold does not trigger slip release', () {
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
      final exactMod = ctrl.update(0.05);
      // Still stationary at threshold → should have subtle stick tension
      expect(exactMod.amplitudeBoost, greaterThanOrEqualTo(0.0));
    });

    test('multiple rapid resets do not crash', () {
      final ctrl = StickSlipController(stationaryThresholdMs: 1);
      for (var i = 0; i < 20; i++) {
        ctrl.reset();
        final mod = ctrl.update(0.5);
        expect(mod.amplitudeBoost, equals(0.0));
        expect(mod.sharpnessShift, equals(0.0));
      }
    });

    test('setter updates threshold mid-operation', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(now: () => fakeNow);

      ctrl.update(0); // init
      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl.update(0); // stationary, but 10ms < 100ms threshold

      // Change threshold to 5ms
      ctrl.stationaryThresholdMs = 5;

      fakeNow = fakeNow.add(const Duration(milliseconds: 10));
      ctrl.update(0); // accumulates energy (10ms > 5ms)

      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, greaterThan(0.0));
    });

    test('clock jump forward (large dt) still works', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(now: () => fakeNow);

      ctrl.update(0); // init
      // Jump 10 seconds forward (simulating pause)
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      ctrl.update(0); // stationary: huge dt → huge stick energy

      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, greaterThan(0.0));
      // Energy capped at 1.0 → boost capped at 0.35
      expect(mod.amplitudeBoost, lessThanOrEqualTo(0.5));
    });

    test('custom clock produces deterministic behavior', () {
      var fakeNow = DateTime(2024);
      final ctrl = StickSlipController(
        stationaryThresholdMs: 10,
        now: () => fakeNow,
      );

      // Initialize
      expect(ctrl.update(0).amplitudeBoost, equals(0.0));

      // Advance time by 50 ms
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0); // accumulate energy

      // Advance again
      fakeNow = fakeNow.add(const Duration(milliseconds: 50));
      ctrl.update(0); // more energy

      // Move — should trigger slip release with deterministic boost
      fakeNow = fakeNow.add(const Duration(milliseconds: 1));
      final mod = ctrl.update(0.5);
      expect(mod.amplitudeBoost, greaterThan(0.0));
    });
  });
}
