import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/physics/paper_texture_noise.dart';

void main() {
  group('PaperTextureNoise', () {
    test('same seed produces deterministic output', () {
      final a = PaperTextureNoise(seed: 42);
      final b = PaperTextureNoise(seed: 42);

      final resultA = a.paperTexture(position: 1.5);
      final resultB = b.paperTexture(position: 1.5);

      expect(resultA, equals(resultB));
    });

    test('output is in [0, 1] range for various positions', () {
      final noise = PaperTextureNoise(seed: 99);

      for (int i = 0; i <= 100; i++) {
        final position = i * 0.1;
        final value = noise.paperTexture(position: position);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(1));
      }
    });

    test('different seeds produce different output', () {
      final a = PaperTextureNoise(seed: 1);
      final b = PaperTextureNoise(seed: 999);

      final resultA = a.paperTexture(position: 2.5);
      final resultB = b.paperTexture(position: 2.5);

      expect(resultA, isNot(equals(resultB)));
    });

    test('higher octaves produce richer variation', () {
      final noise = PaperTextureNoise(seed: 50);

      final lowOct = noise.paperTexture(position: 10.0, octaves: 1);
      final highOct = noise.paperTexture(position: 10.0, octaves: 6);

      // Different octave counts should give different results
      expect(lowOct, isNot(equals(highOct)));
    });

    test('paperTextureFromConfig delegates to paperTexture', () {
      final noise = PaperTextureNoise(seed: 77);

      final direct = noise.paperTexture(
        position: 3.14,
        octaves: 3,
        persistence: 0.5,
        baseFrequency: 0.1,
      );
      final viaConfig = noise.paperTextureFromConfig(
        position: 3.14,
        octaves: 3,
        persistence: 0.5,
        baseFrequency: 0.1,
      );

      expect(direct, equals(viaConfig));
    });

    test('output varies with position', () {
      final noise = PaperTextureNoise(seed: 42);

      final resultA = noise.paperTexture(position: 0.0);
      final resultB = noise.paperTexture(position: 0.5);
      final resultC = noise.paperTexture(position: 99.9);

      // At least one of these should differ from position 0.0
      final allSame = resultA == resultB && resultA == resultC;
      expect(allSame, isFalse);
    });
  });
}
