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

    test('persistence=0 uses only first octave amplitude', () {
      final noise = PaperTextureNoise(seed: 7);
      final single = noise.paperTexture(position: 0.5, octaves: 1);
      final multi = noise.paperTexture(
        position: 0.5,
        octaves: 8,
        persistence: 0,
      );
      // With persistence=0, subsequent octaves have zero amplitude
      expect(multi, equals(single));
    });

    test('very high lacunarity still produces valid output', () {
      final noise = PaperTextureNoise();
      final value = noise.paperTexture(
        position: 0.5,
        lacunarity: 100.0,
      );
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(1));
    });

    test('very large position does not overflow', () {
      final noise = PaperTextureNoise();
      final value = noise.paperTexture(position: 1e6);
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(1));
    });

    test('position=0 produces valid output', () {
      final noise = PaperTextureNoise();
      final value = noise.paperTexture(position: 0);
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(1));
    });

    test('multiple octave values produce valid output', () {
      final noise = PaperTextureNoise();
      for (final oct in [1, 2, 3, 4, 5, 8]) {
        final value = noise.paperTexture(position: 0.7, octaves: oct);
        expect(value, greaterThanOrEqualTo(0), reason: 'octaves=$oct');
        expect(value, lessThanOrEqualTo(1), reason: 'octaves=$oct');
      }
    });

    test('high persistence (0.99) produces smoothly varying noise in range', () {
      final noise = PaperTextureNoise();
      for (int i = 0; i < 200; i++) {
        final value = noise.paperTexture(
          position: i * 0.05,
          persistence: 0.99,
        );
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThanOrEqualTo(1));
      }
    });

    test('default seed is deterministic', () {
      final a = PaperTextureNoise();
      final b = PaperTextureNoise();
      for (int i = 0; i < 10; i++) {
        expect(
          a.paperTexture(position: i * 0.5),
          equals(b.paperTexture(position: i * 0.5)),
        );
      }
    });
  });
}
