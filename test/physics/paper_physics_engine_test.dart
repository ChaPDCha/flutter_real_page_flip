import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/paper_physics.dart';
import 'package:real_page_flip/src/physics/paper_physics_config.dart';

void main() {
  group('PaperPhysicsEngine', () {
    test('basic calculation produces positive amplitude and duration', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame = engine.calculate(dx: 10, foldAngle: 0.5, screenWidth: 400);
      expect(frame.amplitude, greaterThan(0));
      expect(frame.amplitude, lessThanOrEqualTo(1.0));
      expect(frame.durationMs, greaterThan(0));
      expect(frame.sharpness, greaterThan(0));
      expect(frame.sharpness, lessThanOrEqualTo(1.0));
    });

    test('zero dx produces minimal output', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame = engine.calculate(dx: 0, foldAngle: 0, screenWidth: 400);
      expect(frame.rawFriction, greaterThan(0)); // static friction at v=0
      expect(frame.amplitude, lessThan(0.5));
      expect(frame.sharpness, lessThan(0.5));
    });

    test('large dx produces higher values', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frameSmall =
          engine.calculate(dx: 5, foldAngle: 0.5, screenWidth: 400);
      final frameLarge =
          engine.calculate(dx: 100, foldAngle: 0.5, screenWidth: 400);
      expect(frameLarge.amplitude, greaterThan(frameSmall.amplitude));
      expect(
        frameLarge.rawFriction,
        lessThan(frameSmall.rawFriction),
      ); // Stribeck: velocity → lower friction
    });

    test('negative dx produces same result as positive', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final pos = engine.calculate(dx: 10, foldAngle: 0.5, screenWidth: 400);
      final neg = engine.calculate(dx: -10, foldAngle: 0.5, screenWidth: 400);
      expect(neg.amplitude, greaterThan(0));
    });

    test('custom config overrides default', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      const customConfig = PaperPhysicsConfig(
        muStatic: 0.9,
        muKinetic: 0.1,
      );
      final frame = engine.calculate(
        dx: 10,
        foldAngle: 0.5,
        screenWidth: 400,
        customConfig: customConfig,
      );
      expect(frame.amplitude, greaterThan(0));
    });

    test('consecutive calls accumulate noise position', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame1 = engine.calculate(dx: 20, foldAngle: 0.5, screenWidth: 400);
      final frame2 = engine.calculate(dx: 20, foldAngle: 0.5, screenWidth: 400);
      expect(frame2.rawTexture, isNot(equals(frame1.rawTexture)));
    });

    test('reset clears accumulated state', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      engine.calculate(dx: 20, foldAngle: 0.5, screenWidth: 400);
      engine.calculate(dx: 20, foldAngle: 0.5, screenWidth: 400);
      engine.reset();
      final afterReset =
          engine.calculate(dx: 20, foldAngle: 0.5, screenWidth: 400);
      expect(afterReset.amplitude, greaterThan(0));
    });

    test('different page numbers produce different seeds', () {
      final engine1 = PaperPhysicsEngine(pageNumber: 1);
      final engine2 = PaperPhysicsEngine(pageNumber: 2);
      final frame1 =
          engine1.calculate(dx: 10, foldAngle: 0.5, screenWidth: 400);
      final frame2 =
          engine2.calculate(dx: 10, foldAngle: 0.5, screenWidth: 400);
      expect(frame1.rawTexture, isNot(equals(frame2.rawTexture)));
    });

    test('high fold angle produces higher resistance', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final lowAngle = engine.calculate(dx: 10, foldAngle: 0, screenWidth: 400);
      final highAngle =
          engine.calculate(dx: 10, foldAngle: 1, screenWidth: 400);
      expect(highAngle.rawResistance, greaterThan(lowAngle.rawResistance));
    });

    test('very small screenWidth produces clamped velocity', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame = engine.calculate(dx: 100, foldAngle: 0.5, screenWidth: 1);
      expect(frame.amplitude, lessThanOrEqualTo(1.0));
    });

    test('output ranges are bounded', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      for (final dx in [0.0, 1.0, 10.0, 50.0, 200.0]) {
        final frame =
            engine.calculate(dx: dx, foldAngle: 0.5, screenWidth: 400);
        expect(frame.amplitude, inInclusiveRange(0, 1));
        expect(frame.sharpness, inInclusiveRange(0, 1));
        expect(frame.durationMs, greaterThanOrEqualTo(0));
        expect(frame.rawTexture, inInclusiveRange(0, 1));
      }
    });
  });
}
