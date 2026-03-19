import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('Paper Physics Components', () {
    test('PaperPhysicsEngine basic calculation', () {
      final engine = PaperPhysicsEngine(pageNumber: 1);
      final frame = engine.calculate(dx: 10.0, foldAngle: 0.5, screenWidth: 400.0);
      expect(frame.amplitude, greaterThan(0));
      expect(frame.durationMs, greaterThan(0));
    });

    test('PaperPhysicsConfig defaults', () {
      const config = PaperPhysicsConfig();
      expect(config.sigmoidK, equals(6.0));
    });
  });
}
