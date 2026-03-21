import 'dart:math';

/// Generates 1D Perlin-like fractal noise for simulating paper fiber textures.
class PaperTextureNoise {
  /// Creates a texture noise generator with the given [seed].
  PaperTextureNoise({int seed = 42}) : _perm = _buildPermutation(seed);
  final List<int> _perm;

  static List<int> _buildPermutation(int seed) {
    final rng = Random(seed);
    final p = List<int>.generate(256, (i) => i)..shuffle(rng);
    return [...p, ...p];
  }

  double _grad1d(int hash, double x) => (hash & 1) == 0 ? x : -x;

  double _noise1d(double x) {
    final xi = x.floor() & 255;
    final xf = x - x.floor();
    final u = xf * xf * xf * (xf * (xf * 6 - 15) + 10);
    final a = _grad1d(_perm[xi], xf);
    final b = _grad1d(_perm[xi + 1], xf - 1);
    return a + u * (b - a);
  }

  /// Computes a normalized texture value (0.0 to 1.0) at the given [position].
  double paperTexture({
    required double position,
    int octaves = 4,
    double lacunarity = 2.0,
    double persistence = 0.45,
    double baseFrequency = 0.08,
  }) {
    double value = 0;
    double amplitude = 1;
    var frequency = baseFrequency;
    double maxValue = 0;
    for (var i = 0; i < octaves; i++) {
      value += _noise1d(position * frequency) * amplitude;
      maxValue += amplitude;
      amplitude *= persistence;
      frequency *= lacunarity;
    }
    return ((value / maxValue) + 1.0) / 2.0;
  }

  /// Convenience method that computes texture using specific configuration metrics.
  double paperTextureFromConfig({
    required double position,
    required double persistence,
    required int octaves,
    required double baseFrequency,
  }) =>
      paperTexture(
        position: position,
        octaves: octaves,
        persistence: persistence,
        baseFrequency: baseFrequency,
      );
}
