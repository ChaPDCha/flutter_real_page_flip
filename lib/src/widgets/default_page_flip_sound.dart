import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:real_page_flip/src/models/page_flip_sound_player.dart';

/// Final player-volume guard for the default sound's loudness profile.
///
/// The bundled recording is loud; this keeps drag and tap flips quiet even
/// for extreme requested volumes.
@visibleForTesting
double cappedFlipSoundVolume(double requestedVolume) {
  final safeVolume = requestedVolume.isFinite ? requestedVolume : 0.0;
  return (safeVolume.clamp(0.0, 1.0) * 0.4).clamp(0.04, 0.22);
}

/// The package's default page-turn sound.
///
/// Plays the bundled paper sound, or [asset] when given. Nothing is allocated
/// until [warmUp] or the first [play]: an app that disables sound or supplies
/// its own [PageFlipSoundPlayer] never creates an audio player.
///
/// A [play] that arrives before loading has finished is skipped (and starts
/// the load) rather than queued, so a late sound never lands after the turn.
class DefaultPageFlipSound implements PageFlipSoundPlayer {
  /// Creates the default sound player.
  ///
  /// [asset] is a full asset key declared in the host's pubspec, e.g.
  /// `'assets/sounds/my_flip.mp3'`. When null, the bundled sound is used.
  DefaultPageFlipSound({this.asset});

  /// Host asset key to play instead of the bundled sound.
  final String? asset;

  static const String _bundledOpus =
      'packages/real_page_flip/assets/sounds/page_flip.opus';
  static const String _bundledMp3 =
      'packages/real_page_flip/assets/sounds/page_flip.mp3';
  static const int _poolSize = 3;

  final List<AudioPlayer> _pool = <AudioPlayer>[];
  Future<void>? _loading;
  bool _ready = false;
  bool _disposed = false;
  int _next = 0;

  /// Whether a source has loaded and [play] will produce sound.
  @visibleForTesting
  bool get debugIsReady => _ready;

  /// Number of audio players allocated so far (0 until first use).
  @visibleForTesting
  int get debugAllocatedPlayerCount => _pool.length;

  @override
  Future<void> warmUp() => _loading ??= _load();

  Future<void> _load() async {
    final candidates = asset != null
        ? <String>[asset!]
        : const <String>[_bundledOpus, _bundledMp3];
    var loadedAny = false;
    for (var i = 0; i < _poolSize; i++) {
      if (_disposed) return;
      final player = AudioPlayer();
      _pool.add(player);
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
      } on Object {
        // Low-latency mode is an optimisation; keep the default mode.
      }
      player.audioCache.prefix = '';
      for (final source in candidates) {
        if (_disposed) return;
        try {
          await player.setSource(AssetSource(source));
          await player.setReleaseMode(ReleaseMode.stop);
          loadedAny = true;
          break;
        } on Object {
          // Try the next format (opus -> mp3).
        }
      }
    }
    _ready = loadedAny && !_disposed;
  }

  @override
  void play({required double volume}) {
    if (_disposed) return;
    if (!_ready) {
      unawaited(warmUp());
      return;
    }
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    unawaited(_playOn(player, cappedFlipSoundVolume(volume)));
  }

  Future<void> _playOn(AudioPlayer player, double volume) async {
    try {
      await player.stop();
      await player.setVolume(volume);
      await player.seek(Duration.zero);
      await player.resume();
    } on Object {
      // Playback failures must never affect page navigation.
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    for (final player in _pool) {
      unawaited(player.dispose());
    }
    _pool.clear();
  }
}
