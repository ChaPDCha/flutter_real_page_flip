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
        amplitude: 0.5, sharpness: 0.8, durationMs: 60,
        rawResistance: 0.3, rawTexture: 0.6, rawFriction: 0.4,
      );
      const b = PaperPhysicsFrame(
        amplitude: 0.5, sharpness: 0.8, durationMs: 60,
        rawResistance: 0.3, rawTexture: 0.6, rawFriction: 0.4,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality with different amplitude', () {
      const a = PaperPhysicsFrame(
        amplitude: 0.5, sharpness: 0.8, durationMs: 60,
        rawResistance: 0.3, rawTexture: 0.6, rawFriction: 0.4,
      );
      const b = PaperPhysicsFrame(
        amplitude: 0.7, sharpness: 0.8, durationMs: 60,
        rawResistance: 0.3, rawTexture: 0.6, rawFriction: 0.4,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
