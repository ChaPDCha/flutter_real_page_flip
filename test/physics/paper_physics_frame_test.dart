import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('PaperPhysicsFrame', () {
    test('empty frame has all zero values', () {
      final frame = PaperPhysicsFrame.empty;
      expect(frame.amplitude, equals(0));
      expect(frame.sharpness, equals(0));
      expect(frame.durationMs, equals(0));
      expect(frame.rawResistance, equals(0));
      expect(frame.rawTexture, equals(0));
      expect(frame.rawFriction, equals(0));
      expect(frame.stickSlipEvent, isNull);
    });

    test('constructor assigns fields correctly', () {
      const frame = PaperPhysicsFrame(
        amplitude: 0.5,
        sharpness: 0.8,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
        stickSlipEvent: null,
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

    test('inequality with different sharpness', () {
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
        sharpness: 0.3,
        durationMs: 60,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different durationMs', () {
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
        durationMs: 30,
        rawResistance: 0.3,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different rawResistance', () {
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
        rawResistance: 0.7,
        rawTexture: 0.6,
        rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different rawTexture', () {
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
        rawTexture: 0.9,
        rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different rawFriction', () {
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
        rawFriction: 0.7,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality with different stickSlipEvent (null vs non-null)', () {
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
        stickSlipEvent: StickSlipEvent.slipRelease(intensity: 0.5),
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
