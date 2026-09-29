import 'dart:async';

/// Plays the page-turn sound.
///
/// Sound is an optional extra, not part of the flip engine's core. The package
/// ships one default sound (`DefaultPageFlipSound`); implement this interface
/// to change the sound or add behaviour (per-book sounds, a different audio
/// backend, desktop support) without touching haptics.
///
/// ```dart
/// class MyFlipSound implements PageFlipSoundPlayer {
///   @override
///   Future<void> warmUp() async { /* preload */ }
///
///   @override
///   Future<void> play({required double volume}) async { /* play */ }
///
///   @override
///   void dispose() {}
/// }
///
/// PageFlipWidget(
///   config: PageFlipConfig(soundPlayer: mySound),
///   ...
/// )
/// ```
///
/// Ownership: a player passed through `PageFlipConfig.soundPlayer` belongs to
/// the host. The engine never calls [dispose] on it; the host must dispose it
/// when it is no longer needed. The engine only disposes players it created.
abstract class PageFlipSoundPlayer {
  /// Const constructor so implementations can be const.
  const PageFlipSoundPlayer();

  /// Optional preload, called once sound is enabled and the widget has laid
  /// out, so the first turn does not pay the load latency. Default: no-op.
  FutureOr<void> warmUp() {}

  /// Plays the turn sound.
  ///
  /// [volume] is the engine's suggested loudness in `0.0..1.0`, scaled by the
  /// release velocity (a fast flick is louder than a slow turn). Players may
  /// remap it to their own loudness profile.
  FutureOr<void> play({required double volume});

  /// Releases resources. Only called for players the engine created.
  void dispose() {}
}
