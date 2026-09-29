import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

/// Platform channel served by this package's own plugin (Android `SoundPool`,
/// iOS `AVAudioPlayer`, web `HTMLAudioElement`).
@visibleForTesting
const MethodChannel pageFlipSoundChannel =
    MethodChannel('com.chapdcha.real_page_flip/sound');

/// Whether the package provides a default sound on [platform].
///
/// Desktop (macOS, Windows, Linux) has no default sound by design. Supply a
/// [PageFlipSoundPlayer] there if you want one.
@visibleForTesting
bool platformHasDefaultSound({
  required TargetPlatform platform,
  required bool isWeb,
}) =>
    isWeb ||
    platform == TargetPlatform.android ||
    platform == TargetPlatform.iOS;

/// The package's default page-turn sound.
///
/// Plays the bundled paper sound, or [asset] when given, through this
/// package's own plugin — no third-party audio dependency. Available on
/// Android, iOS, and web; a silent no-op on desktop.
///
/// Nothing is loaded until [warmUp] or the first [play]: an app that disables
/// sound or supplies its own [PageFlipSoundPlayer] never touches the audio
/// stack. A [play] that arrives before loading has finished is skipped (and
/// starts the load) rather than queued, so a late sound never lands after
/// the turn.
class DefaultPageFlipSound implements PageFlipSoundPlayer {
  /// Creates the default sound player.
  ///
  /// [asset] is a full asset key declared in the host's pubspec, e.g.
  /// `'assets/sounds/my_flip.mp3'`. When null, the bundled sound is used.
  ///
  /// [isSupported] overrides platform detection (for tests); by default the
  /// sound is available on Android, iOS, and web.
  DefaultPageFlipSound({this.asset, bool? isSupported})
      : _isSupported = isSupported ??
            platformHasDefaultSound(
              platform: defaultTargetPlatform,
              isWeb: kIsWeb,
            ),
        _id = _nextId++;

  static int _nextId = 1;

  static const String _bundledMp3 =
      'packages/real_page_flip/assets/sounds/page_flip.mp3';
  static const String _bundledOpus =
      'packages/real_page_flip/assets/sounds/page_flip.opus';

  /// Host asset key to play instead of the bundled sound.
  final String? asset;

  final bool _isSupported;
  final int _id;
  Future<void>? _loading;
  bool _ready = false;
  bool _disposed = false;

  /// Whether a source has loaded and [play] will produce sound.
  @visibleForTesting
  bool get debugIsReady => _ready;

  /// Whether loading has been started.
  @visibleForTesting
  bool get debugLoadStarted => _loading != null;

  @override
  Future<void> warmUp() => _loading ??= _load();

  Future<void> _load() async {
    if (!_isSupported) return;
    // mp3 decodes everywhere (AVAudioPlayer cannot read Ogg/Opus); opus is the
    // smaller fallback for platforms that can.
    final candidates = asset != null
        ? <String>[asset!]
        : const <String>[_bundledMp3, _bundledOpus];
    for (final source in candidates) {
      if (_disposed) return;
      final loaded = await _invoke<bool>(
        'load',
        <String, Object>{'id': _id, 'asset': source},
      );
      if (loaded ?? false) {
        if (_disposed) {
          await _invoke<void>('unload', <String, Object>{'id': _id});
          return;
        }
        _ready = true;
        return;
      }
    }
  }

  @override
  void play({required double volume}) {
    if (_disposed || !_isSupported) return;
    if (!_ready) {
      unawaited(warmUp());
      return;
    }
    unawaited(
      _invoke<bool>(
        'play',
        <String, Object>{'id': _id, 'volume': cappedFlipSoundVolume(volume)},
      ),
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ready = false;
    if (_loading != null && _isSupported) {
      unawaited(_invoke<void>('unload', <String, Object>{'id': _id}));
    }
  }

  /// Channel call that never throws: sound must not affect navigation.
  static Future<T?> _invoke<T>(String method, Map<String, Object> args) async {
    try {
      return await pageFlipSoundChannel.invokeMethod<T>(method, args);
    } on Object {
      return null;
    }
  }
}
