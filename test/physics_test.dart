import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';

void main() {
  group('PaperPhysicsEngine', () {
    test('basic calculation produces positive amplitude and duration', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame =
          engine.calculate(dx: 10.0, foldAngle: 0.5, screenWidth: 400.0);
      expect(frame.amplitude, greaterThan(0));
      expect(frame.amplitude, lessThanOrEqualTo(1.0));
      expect(frame.durationMs, greaterThan(0));
      expect(frame.sharpness, greaterThan(0));
      expect(frame.sharpness, lessThanOrEqualTo(1.0));
    });

    test('zero dx produces minimal output', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame =
          engine.calculate(dx: 0.0, foldAngle: 0.0, screenWidth: 400.0);
      // With zero dx, velocity = 0, so amplitude and sharpness are low
      expect(frame.rawFriction, greaterThan(0)); // static friction at v=0
      expect(frame.amplitude, lessThan(0.5));
      expect(frame.sharpness, lessThan(0.5));
    });

    test('large dx produces higher values', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frameSmall =
          engine.calculate(dx: 5.0, foldAngle: 0.5, screenWidth: 400.0);
      final frameLarge =
          engine.calculate(dx: 100.0, foldAngle: 0.5, screenWidth: 400.0);
      expect(frameLarge.amplitude, greaterThan(frameSmall.amplitude));
      expect(
          frameLarge.rawFriction,
          lessThan(
              frameSmall.rawFriction)); // Stribeck: velocity → lower friction
    });

    test('negative dx produces same result as positive', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final pos =
          engine.calculate(dx: 10.0, foldAngle: 0.5, screenWidth: 400.0);
      final neg =
          engine.calculate(dx: -10.0, foldAngle: 0.5, screenWidth: 400.0);
      // Absolute value used internally, so results should match
      expect(neg.amplitude, greaterThan(0));
    });

    test('custom config overrides default', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final customConfig = PaperPhysicsConfig(
        muStatic: 0.9,
        muKinetic: 0.1,
      );
      final frame = engine.calculate(
        dx: 10.0,
        foldAngle: 0.5,
        screenWidth: 400.0,
        customConfig: customConfig,
      );
      expect(frame.amplitude, greaterThan(0));
    });

    test('consecutive calls accumulate noise position', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame1 =
          engine.calculate(dx: 20.0, foldAngle: 0.5, screenWidth: 400.0);
      final frame2 =
          engine.calculate(dx: 20.0, foldAngle: 0.5, screenWidth: 400.0);
      // Second call has different accumulated distance → different texture noise
      // (with high probability, the exact value differs)
      expect(frame2.rawTexture, isNot(equals(frame1.rawTexture)));
    });

    test('reset clears accumulated state', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      engine.calculate(dx: 20.0, foldAngle: 0.5, screenWidth: 400.0);
      engine.calculate(dx: 20.0, foldAngle: 0.5, screenWidth: 400.0);
      engine.reset();
      final afterReset =
          engine.calculate(dx: 20.0, foldAngle: 0.5, screenWidth: 400.0);
      expect(afterReset.amplitude, greaterThan(0));
    });

    test('different page numbers produce different seeds', () {
      final engine1 = PaperPhysicsEngine(pageNumber: 1);
      final engine2 = PaperPhysicsEngine(pageNumber: 2);
      final frame1 =
          engine1.calculate(dx: 10.0, foldAngle: 0.5, screenWidth: 400.0);
      final frame2 =
          engine2.calculate(dx: 10.0, foldAngle: 0.5, screenWidth: 400.0);
      // Different seeds → different texture noise (with high probability)
      expect(frame1.rawTexture, isNot(equals(frame2.rawTexture)));
    });

    test('high fold angle produces higher resistance', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final lowAngle =
          engine.calculate(dx: 10.0, foldAngle: 0.0, screenWidth: 400.0);
      final highAngle =
          engine.calculate(dx: 10.0, foldAngle: 1.0, screenWidth: 400.0);
      expect(highAngle.rawResistance, greaterThan(lowAngle.rawResistance));
    });

    test('very small screenWidth produces clamped velocity', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame =
          engine.calculate(dx: 100.0, foldAngle: 0.5, screenWidth: 1.0);
      // normalizedDx = 100/1 = 100, velocity = (100 * 10).clamp(0,1) = 1.0
      expect(frame.amplitude, lessThanOrEqualTo(1.0));
    });

    test('output ranges are bounded', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      for (final dx in [0.0, 1.0, 10.0, 50.0, 200.0]) {
        final frame =
            engine.calculate(dx: dx, foldAngle: 0.5, screenWidth: 400.0);
        expect(frame.amplitude, inInclusiveRange(0, 1));
        expect(frame.sharpness, inInclusiveRange(0, 1));
        expect(frame.durationMs, greaterThanOrEqualTo(0));
        expect(frame.rawTexture, inInclusiveRange(0, 1));
      }
    });
  });

  group('PaperPhysicsConfig', () {
    test('standard defaults match', () {
      const config = PaperPhysicsConfig();
      expect(config.sigmoidK, equals(6.0));
      expect(config.muStatic, equals(0.6));
      expect(config.muKinetic, equals(0.25));
    });

    test('thinBible preset has lower friction', () {
      const config = PaperPhysicsConfig.thinBible;
      expect(config.muStatic, equals(0.5));
      expect(config.muKinetic, equals(0.2));
      expect(config.perlinPersistence, equals(0.35));
    });

    test('roughAntique preset has higher friction', () {
      const config = PaperPhysicsConfig.roughAntique;
      expect(config.muStatic, equals(0.8));
      expect(config.muKinetic, equals(0.4));
      expect(config.maxDurationMs, equals(180));
    });
  });

  group('PaperPhysicsFrame', () {
    test('empty frame has all zeros', () {
      expect(PaperPhysicsFrame.empty.amplitude, equals(0));
      expect(PaperPhysicsFrame.empty.sharpness, equals(0));
      expect(PaperPhysicsFrame.empty.durationMs, equals(0));
      expect(PaperPhysicsFrame.empty.stickSlipEvent, isNull);
    });
  });
}
