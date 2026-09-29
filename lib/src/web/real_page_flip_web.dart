import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

/// Web implementation of the real_page_flip plugin.
///
/// Haptics have no web channel (calls fall back to Flutter's built-in
/// `HapticFeedback`). The default page-turn sound is served on
/// `com.chapdcha.real_page_flip/sound` with `HTMLAudioElement`s, so the Dart
/// side uses one code path on every platform.
class RealPageFlipWeb {
  RealPageFlipWeb._();

  static const int _voiceCount = 3;

  final Map<int, List<web.HTMLAudioElement>> _voicesById =
      <int, List<web.HTMLAudioElement>>{};
  final Map<int, int> _nextVoiceById = <int, int>{};

  /// Called by Flutter's generated web plugin registrant.
  static void registerWith(Registrar registrar) {
    final plugin = RealPageFlipWeb._();
    MethodChannel(
      'com.chapdcha.real_page_flip/sound',
      const StandardMethodCodec(),
      registrar,
    ).setMethodCallHandler(plugin._handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = (call.arguments as Map<Object?, Object?>?) ?? const {};
    final id = args['id'];
    switch (call.method) {
      case 'load':
        final asset = args['asset'];
        if (id is! int || asset is! String) return false;
        return _load(id, asset);
      case 'play':
        if (id is! int) return false;
        final volume = args['volume'];
        return _play(id, volume is num ? volume.toDouble() : 0.3);
      case 'unload':
        if (id is int) _unload(id);
        return null;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          message: '${call.method} is not implemented on web',
        );
    }
  }

  /// Prepares [asset] for playback.
  ///
  /// Does not wait for `canplaythrough`: mobile Safari ignores `preload` until
  /// a user gesture, so that event may never fire during warm-up. Format
  /// support is decided synchronously with `canPlayType` instead, which lets
  /// Dart fall back (mp3 -> opus) on browsers that cannot decode one of them.
  bool _load(int id, String asset) {
    _unload(id);
    final probe = web.HTMLAudioElement();
    final mime = _mimeForAsset(asset);
    if (mime != null && probe.canPlayType(mime).isEmpty) return false;

    final url = ui_web.assetManager.getAssetUrl(asset);
    _voicesById[id] = <web.HTMLAudioElement>[
      for (var i = 0; i < _voiceCount; i++)
        web.HTMLAudioElement()
          ..preload = 'auto'
          ..src = url,
    ];
    _nextVoiceById[id] = 0;
    return true;
  }

  static String? _mimeForAsset(String asset) {
    final dot = asset.lastIndexOf('.');
    if (dot < 0) return null;
    return switch (asset.substring(dot + 1).toLowerCase()) {
      'mp3' => 'audio/mpeg',
      'opus' => 'audio/ogg; codecs=opus',
      'ogg' || 'oga' => 'audio/ogg',
      'wav' => 'audio/wav',
      'm4a' || 'aac' || 'mp4' => 'audio/mp4',
      'webm' => 'audio/webm',
      _ => null,
    };
  }

  Future<bool> _play(int id, double volume) async {
    final voices = _voicesById[id];
    if (voices == null || voices.isEmpty) return false;
    final index = _nextVoiceById[id] ?? 0;
    _nextVoiceById[id] = (index + 1) % voices.length;
    final audio = voices[index]
      ..pause()
      ..currentTime = 0
      ..volume = volume.clamp(0.0, 1.0);
    try {
      await audio.play().toDart;
      return true;
    } on Object {
      // Autoplay policy (no user gesture yet) or a decode error.
      return false;
    }
  }

  void _unload(int id) {
    final voices = _voicesById.remove(id);
    _nextVoiceById.remove(id);
    if (voices == null) return;
    for (final audio in voices) {
      audio
        ..pause()
        ..removeAttribute('src')
        ..load();
    }
  }
}
