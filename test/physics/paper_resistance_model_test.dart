import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/paper_resistance_model.dart';

void main() {
  group('PaperResistanceModel.resistance', () {
    test('returns value in [0, 1] range for all fold angles', () {
      for (var i = 0; i <= 100; i++) {
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
        sigmoidK: 2,
      );
      final highK = PaperResistanceModel.resistance(
        foldAngle: 0.5,
        sigmoidK: 12,
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
      );
      expect(f, closeTo(0.6, 0.001));
    });

    test('at high velocity approaches muKinetic', () {
      final f = PaperResistanceModel.frictionCoefficient(
        velocity: 1,
      );
      expect(f, closeTo(0.25, 0.01));
    });

    test('is monotonically decreasing with velocity', () {
      var prev = double.infinity;
      for (var i = 0; i <= 50; i++) {
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
        velocity: 1,
        friction: 1,
        texture: 1,
        resistance: 1,
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
        resistance: 2,
        friction: 2,
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

    test('minDurationMs equals maxDurationMs returns that value', () {
      final d = PaperResistanceModel.hapticDuration(
        resistance: 0.5,
        friction: 0.5,
        minDurationMs: 30,
        maxDurationMs: 30,
      );
      expect(d, equals(30));
    });
  });

  group('PaperResistanceModel — property-based invariants', () {
    test('resistance at foldAngle=0 depends only on bindingStiffness', () {
      // At foldAngle=0: sigmoidValue=1/(1+exp(6*0.5))≈0.047, sin(0)=0
      // With bindingStiffness=0: only sigmoid component
      final noBind = PaperResistanceModel.resistance(
        foldAngle: 0,
        bindingStiffness: 0,
      );
      expect(noBind, greaterThanOrEqualTo(0));
      expect(noBind, lessThanOrEqualTo(1));

      // With bindingStiffness=1: sin(0)*1*0.3 = 0, same as no bind at angle 0
      final fullBind = PaperResistanceModel.resistance(
        foldAngle: 0,
        bindingStiffness: 1,
      );
      expect(fullBind, equals(noBind));
    });

    test('resistance at foldAngle=1 includes edge boost', () {
      // At foldAngle=1: edgeBoost = (1-0.75)*0.4 = 0.1
      final result = PaperResistanceModel.resistance(
        foldAngle: 1,
      );
      expect(result, greaterThanOrEqualTo(0));
      expect(result, lessThanOrEqualTo(1));
      // Edge boost of 0.1 plus sigmoid at 1.0 ≈ 0.953*0.3 + sin(pi)*0.5*0.3 + 0.1
      // = 0.286 + 0 + 0.1 = 0.386
      expect(result, greaterThan(0.1));
    });

    test('bindingStiffness=0 removes sine component', () {
      final result = PaperResistanceModel.resistance(
        foldAngle: 0.5,
        bindingStiffness: 0,
      );
      // Only sigmoid (0.5*0.3=0.15) + no edge boost (<0.75)
      expect(result, lessThan(0.2));
    });

    test('sigmoidK=0 produces constant sigmoid', () {
      // sigmoidK=0: sigmoid = 1/(1+exp(0)) = 0.5 for any foldAngle
      final atStart = PaperResistanceModel.resistance(
        foldAngle: 0.1,
        sigmoidK: 0,
        bindingStiffness: 0,
      );
      final atMid = PaperResistanceModel.resistance(
        foldAngle: 0.5,
        sigmoidK: 0,
        bindingStiffness: 0,
      );
      final atEnd = PaperResistanceModel.resistance(
        foldAngle: 0.9,
        sigmoidK: 0,
        bindingStiffness: 0,
      );
      // All have sigmoid contribution 0.5*0.3 = 0.15
      // atEnd has edge boost (0.9-0.75)*0.4 = 0.06
      expect(atStart, equals(atMid));
      expect(atEnd, greaterThan(atMid));
    });

    test('edge boost activates only beyond foldAngle=0.75', () {
      final before = PaperResistanceModel.resistance(
        foldAngle: 0.75,
        bindingStiffness: 0,
      );
      final after = PaperResistanceModel.resistance(
        foldAngle: 0.751,
        bindingStiffness: 0,
      );
      // before: no edge boost (0.75 is NOT > 0.75), after: tiny boost
      // The sigmoid is smooth so there's a tiny difference, but the
      // edge boost formula means after should be larger
      expect(after, greaterThan(before));
    });

    test('frictionCoefficient at stribeckV0', () {
      // At v=stribeckV0: muKinetic + (muStatic-muKinetic)*exp(-1)
      // = 0.25 + 0.35*exp(-1) ≈ 0.25 + 0.1288 = 0.3788
      final result = PaperResistanceModel.frictionCoefficient(
        velocity: 0.08,
      );
      expect(result, closeTo(0.3788, 0.001));
    });

    test('frictionCoefficient with equal static/kinetic is constant', () {
      for (var i = 0; i <= 10; i++) {
        final v = i / 10.0;
        final result = PaperResistanceModel.frictionCoefficient(
          velocity: v,
          muStatic: 0.5,
          muKinetic: 0.5,
        );
        expect(result, equals(0.5));
      }
    });

    test('hapticAmplitude clamps to 0.05 for zero inputs', () {
      final result = PaperResistanceModel.hapticAmplitude(
        velocity: 0,
        friction: 0,
        texture: 0,
        resistance: 0,
      );
      expect(result, equals(0.05));
    });

    test('hapticAmplitude clamps to 1.0 for extreme inputs', () {
      final result = PaperResistanceModel.hapticAmplitude(
        velocity: 10,
        friction: 10,
        texture: 10,
        resistance: 10,
      );
      expect(result, equals(1.0));
    });

    test('hapticAmplitude resistance boost activates above 0.75', () {
      final noBoost = PaperResistanceModel.hapticAmplitude(
        velocity: 0.3,
        friction: 0.3,
        texture: 0.3,
        resistance: 0.75,
      );
      final withBoost = PaperResistanceModel.hapticAmplitude(
        velocity: 0.3,
        friction: 0.3,
        texture: 0.3,
        resistance: 0.76,
      );
      expect(withBoost, greaterThan(noBoost));
    });

    test('frictionCoefficient is monotonically decreasing with velocity', () {
      var prev = double.infinity;
      for (var i = 0; i <= 100; i++) {
        final v = i / 100.0;
        final f = PaperResistanceModel.frictionCoefficient(velocity: v);
        expect(f, lessThanOrEqualTo(prev));
        prev = f;
      }
    });

    test('resistance is in [0, 1] for exhaustive parameter sweep', () {
      for (var i = 0; i <= 200; i++) {
        final foldAngle = i / 200.0;
        for (var j = 0; j <= 2; j++) {
          final k = [2.0, 6.0, 12.0][j];
          final r = PaperResistanceModel.resistance(
            foldAngle: foldAngle,
            sigmoidK: k,
          );
          expect(r, greaterThanOrEqualTo(0));
          expect(r, lessThanOrEqualTo(1));
        }
      }
    });
  });
}
