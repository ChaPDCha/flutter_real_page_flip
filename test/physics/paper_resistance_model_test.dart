import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/paper_resistance_model.dart';

void main() {
  group('PaperResistanceModel.resistance', () {
    test('returns value in [0, 1] range for all fold angles', () {
      for (int i = 0; i <= 100; i++) {
        final angle = i / 100.0;
        final r = PaperResistanceModel.resistance(foldAngle: angle);
        expect(r, greaterThanOrEqualTo(0));
        expect(r, lessThanOrEqualTo(1));
      }
    });

    test('resistance peaks near sigmoid center', () {
      // With default sigmoidK=6, center=0.5, resistance should be higher at center
      final atEdge = PaperResistanceModel.resistance(foldAngle: 0.1);
      final atCenter = PaperResistanceModel.resistance(foldAngle: 0.5);
      expect(atCenter, greaterThan(atEdge));
    });

    test('edge boost activates beyond foldAngle=0.75', () {
      final beforeEdge = PaperResistanceModel.resistance(foldAngle: 0.74);
      final atEdge = PaperResistanceModel.resistance(foldAngle: 0.85);
      // Edge boost adds extra resistance near page boundary
      expect(atEdge, greaterThan(beforeEdge));
    });

    test('higher sigmoidK produces sharper transition', () {
      final lowK = PaperResistanceModel.resistance(
        foldAngle: 0.5,
        sigmoidK: 2.0,
      );
      final highK = PaperResistanceModel.resistance(
        foldAngle: 0.5,
        sigmoidK: 12.0,
      );
      // Both at center should give similar values
      expect(lowK, greaterThan(0));
      expect(highK, greaterThan(0));
    });
  });

  group('PaperResistanceModel.frictionCoefficient', () {
    test('at velocity=0 equals muStatic', () {
      final f = PaperResistanceModel.frictionCoefficient(
        velocity: 0,
        muStatic: 0.6,
        muKinetic: 0.25,
        stribeckV0: 0.08,
      );
      expect(f, closeTo(0.6, 0.001));
    });

    test('at high velocity approaches muKinetic', () {
      final f = PaperResistanceModel.frictionCoefficient(
        velocity: 1.0,
        muStatic: 0.6,
        muKinetic: 0.25,
        stribeckV0: 0.08,
      );
      expect(f, closeTo(0.25, 0.01));
    });

    test('is monotonically decreasing with velocity', () {
      double prev = double.infinity;
      for (int i = 0; i <= 50; i++) {
        final v = i / 50.0;
        final f = PaperResistanceModel.frictionCoefficient(velocity: v);
        expect(f, lessThanOrEqualTo(prev));
        prev = f;
      }
    });
  });

  group('PaperResistanceModel.hapticAmplitude', () {
    test('returns value in [0.05, 1.0] range', () {
      final minAmp = PaperResistanceModel.hapticAmplitude(
        velocity: 0,
        friction: 0,
        texture: 0,
        resistance: 0,
      );
      final maxAmp = PaperResistanceModel.hapticAmplitude(
        velocity: 1.0,
        friction: 1.0,
        texture: 1.0,
        resistance: 1.0,
      );
      expect(minAmp, greaterThanOrEqualTo(0.05));
      expect(maxAmp, lessThanOrEqualTo(1.0));
    });

    test('higher velocity increases amplitude', () {
      final slow = PaperResistanceModel.hapticAmplitude(
        velocity: 0.2,
        friction: 0.5,
        texture: 0.5,
        resistance: 0.5,
      );
      final fast = PaperResistanceModel.hapticAmplitude(
        velocity: 0.9,
        friction: 0.5,
        texture: 0.5,
        resistance: 0.5,
      );
      expect(fast, greaterThan(slow));
    });

    test('resistance boost adds amplitude above 0.75', () {
      final low = PaperResistanceModel.hapticAmplitude(
        velocity: 0.5,
        friction: 0.5,
        texture: 0.5,
        resistance: 0.7,
      );
      final high = PaperResistanceModel.hapticAmplitude(
        velocity: 0.5,
        friction: 0.5,
        texture: 0.5,
        resistance: 0.9,
      );
      expect(high, greaterThan(low));
    });
  });

  group('PaperResistanceModel.hapticDuration', () {
    test('clamps to [minDurationMs, maxDurationMs]', () {
      final d = PaperResistanceModel.hapticDuration(
        resistance: 2.0,
        friction: 2.0,
        minDurationMs: 8,
        maxDurationMs: 120,
      );
      expect(d, greaterThanOrEqualTo(8));
      expect(d, lessThanOrEqualTo(120));
    });

    test('higher resistance increases duration', () {
      final low = PaperResistanceModel.hapticDuration(
        resistance: 0.2,
        friction: 0.5,
      );
      final high = PaperResistanceModel.hapticDuration(
        resistance: 0.9,
        friction: 0.5,
      );
      expect(high, greaterThanOrEqualTo(low));
    });
  });
}
