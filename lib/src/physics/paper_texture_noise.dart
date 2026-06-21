import 'dart:math';

/// Generates 1D Perlin-like noise for paper texture simulation.
class PaperTextureNoise {
  /// Creates a [PaperTextureNoise] with an optional seed value.
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

  /// Generates a paper texture value using fractal Brownian motion noise.
  ///
  /// Uses multiple octaves of 1D Perlin-like noise to produce a natural
  /// paper fibre texture (0.0 to 1.0).
  double paperTexture({
    /// Position along the paper surface.
    required double position,

    /// Number of noise octaves to layer.
    int octaves = 4,

    /// Frequency multiplier between octaves.
    double lacunarity = 2.0,

    /// Amplitude persistence (how quickly amplitude decays per octave).
    double persistence = 0.45,

    /// Base frequency for the first octave.
    double baseFrequency = 0.08,
  }) {
    double value = 0;
    double amplitude = 1;
    double frequency = baseFrequency;
    double maxValue = 0;
    for (var i = 0; i < octaves; i++) {
      value += _noise1d(position * frequency) * amplitude;
      maxValue += amplitude;
      amplitude *= persistence;
      frequency *= lacunarity;
    }
    return ((value / maxValue) + 1.0) / 2.0;
  }

  /// Convenience wrapper around [paperTexture] that reads config values directly.
  double paperTextureFromConfig({
    /// Position along the paper surface.
    required double position,

    /// Amplitude persistence (from config).
    required double persistence,

    /// Number of noise octaves (from config).
    required int octaves,

    /// Base frequency (from config).
    required double baseFrequency,
  }) =>
      paperTexture(
        position: position,
        octaves: octaves,
        persistence: persistence,
        baseFrequency: baseFrequency,
      );
}
