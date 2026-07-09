import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/paper_physics_frame.dart';
import 'package:real_page_flip/src/physics/stick_slip_controller.dart';

void main() {
  group('PaperPhysicsFrame', () {
    test('empty frame has all zero values', () {
      const frame = PaperPhysicsFrame.empty;
      expect(frame.amplitude, equals(0));
      expect(frame.sharpness, equals(0));
      expect(frame.durationMs, equals(0));
      expect(frame.rawResistance, equals(0));
      expect(frame.rawTexture, equals(0));
      expect(frame.rawFriction, equals(0));
      expect(frame.stickSlipModulation, isNull);
    });

    test('constructor assigns fields correctly', () {
      const frame = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(frame.amplitude, equals(0.5));
      expect(frame.sharpness, equals(0.8));
      expect(frame.durationMs, equals(60));
      expect(frame.rawResistance, equals(0.3));
      expect(frame.rawTexture, equals(0.6));
      expect(frame.rawFriction, equals(0.4));
    });

    test('equality with same values', () {
      const a = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      const b = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different amplitude', () {
      const a = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      const b = PaperPhysicsFrame(
        amplitude: 0.7,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different stickSlipModulation (null vs non-null)', () {
      const a = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      final b = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
        stickSlipModulation: const StickSlipModulation(
          amplitudeBoost: 0.3,
          sharpnessShift: 0.1,
        ),
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode consistent with equality', () {
      const a = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      const b = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      const c = PaperPhysicsFrame(
        amplitude: 0.7,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a.hashCode, equals(b.hashCode));
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });
  });
}
