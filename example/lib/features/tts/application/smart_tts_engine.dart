import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'supertonic_tts_service.dart';

/// Smart TTS engine with three-tier cache and predictive pre-generation.
///
/// Architecture (fast → slow):
///   Tier 1 — Memory LRU cache (last 5 pages, instant replay)
///   Tier 2 — WAV disk cache (persistent across sessions)
///   Tier 3 — On-device ONNX synthesis (first visit only)
///
/// Pre-generation: while the user reads silently, upcoming pages are
/// synthesised in the background so TTS is instant when requested.
class SmartTtsEngine {
  final SupertonicTtsService _tts;
  final AudioPlayer _player;

  // ── Memory cache ───────────────────────────────────────────────────
  final LinkedHashMap<String, Uint8List> _memCache = LinkedHashMap();
  static const int _memCacheMax = 5;

  // ── Disk cache ─────────────────────────────────────────────────────
  String? _cacheRoot;

  // ── State ──────────────────────────────────────────────────────────
  bool _isSpeaking = false;
  bool _isInitialized = false;

  // ── Highlight streaming ────────────────────────────────────────────
  final _highlightController = StreamController<TtsWordHighlight?>.broadcast();
  Stream<TtsWordHighlight?> get highlightStream => _highlightController.stream;
  List<TtsWordAlignment> _activeAlignments = [];
  StreamSubscription? _positionSubscription;

  // ── Public API ─────────────────────────────────────────────────────

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  bool get isSpeaking => _isSpeaking;

  SmartTtsEngine({SupertonicTtsService? ttsService, AudioPlayer? player})
    : _tts = ttsService ?? SupertonicTtsService(),
      _player = player ?? AudioPlayer();

  /// Speak [text] from [bookId]/chapter/[pageIndex].
  ///
  /// Cache lookup (memory → disk) first. On miss, synthesises the full page
  /// (async — the native ONNX model runs on a background thread so the UI
  /// stays responsive). The result is cached for instant replay next time.
  Future<void> speak({
    required String bookId,
    required String text,
    required int chapterIndex,
    required int pageIndex,
    String language = 'ko',
    double speed = 1.0,
  }) async {
    await stop();

    // Tier 1 — Memory cache
    {
      final cached = _memCache['$bookId:$chapterIndex:$pageIndex'];
      if (cached != null) {
        await _playWav(cached, text);
        return;
      }
    }

    // Tier 2 — Disk cache
    {
      final cached = await _readDiskCache(bookId, chapterIndex, pageIndex);
      if (cached != null) {
        _memCache['$bookId:$chapterIndex:$pageIndex'] = cached;
        _trimMemCache();
        await _playWav(cached, text);
        return;
      }
    }

    // Tier 3 — Full-page synthesis (async, non-blocking)
    await _init();
    try {
      final synth = await _tts.synthesize(
        text,
        language: language,
        speed: speed,
      );
      final wavBytes = _pcmToWav(synth.pcmSamples, synth.sampleRate);

      // Cache before playing so the file is persisted even if play fails
      await _writeDiskCache(bookId, chapterIndex, pageIndex, wavBytes);
      _memCache['$bookId:$chapterIndex:$pageIndex'] = wavBytes;
      _trimMemCache();

      await _playWav(wavBytes, text);
    } catch (e) {
      debugPrint('SmartTtsEngine: synthesis failed: $e');
      rethrow;
    }
  }

  /// Pre-generate TTS audio for [pageIndex] in the background.
  ///
  /// The reader controller should call this from [onPageChanged] so that
  /// upcoming pages are cached before the user taps the TTS button.
  Future<void> preGeneratePage(
    String bookId,
    String text,
    int chapterIndex,
    int pageIndex, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    if (text.isEmpty) return;
    final key = '$bookId:$chapterIndex:$pageIndex';
    if (_memCache.containsKey(key)) return;
    final cached = await _readDiskCache(bookId, chapterIndex, pageIndex);
    if (cached != null) {
      _memCache[key] = cached;
      _trimMemCache();
      return;
    }

    try {
      await _init();
      final synth = await _tts.synthesize(
        text,
        language: language,
        speed: speed,
      );
      final wavBytes = _pcmToWav(synth.pcmSamples, synth.sampleRate);
      await _writeDiskCache(bookId, chapterIndex, pageIndex, wavBytes);
      _memCache[key] = wavBytes;
      _trimMemCache();
    } catch (e) {
      debugPrint('SmartTtsEngine: pre-gen page $pageIndex failed: $e');
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();

  Future<void> stop() async {
    _isSpeaking = false;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _highlightController.add(null);
    await _player.stop();
    _activeAlignments = [];
  }

  void dispose() {
    _positionSubscription?.cancel();
    _highlightController.close();
    _player.dispose();
  }

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      await _tts.init();
      _isInitialized = true;
    } catch (e) {
      debugPrint('SmartTtsEngine: TTS init failed — $e');
      rethrow;
    }
  }

  // ── Memory cache helpers ───────────────────────────────────────────

  void _trimMemCache() {
    while (_memCache.length > _memCacheMax) {
      _memCache.remove(_memCache.keys.first);
    }
  }

  // ── Disk cache helpers ─────────────────────────────────────────────

  Future<String> _ensureCacheRoot() async {
    if (_cacheRoot == null) {
      final dir = await getTemporaryDirectory();
      _cacheRoot = '${dir.path}/tts_cache';
      await Directory(_cacheRoot!).create(recursive: true);
    }
    return _cacheRoot!;
  }

  String _cacheRelPath(String bookId, int ch, int page) =>
      '$bookId/${ch}_$page.ttsc';

  Future<Uint8List?> _readDiskCache(String bookId, int ch, int page) async {
    try {
      final root = await _ensureCacheRoot();
      final file = File('$root/${_cacheRelPath(bookId, ch, page)}');
      if (!file.existsSync()) return null;
      return file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDiskCache(
    String bookId,
    int ch,
    int page,
    Uint8List data,
  ) async {
    try {
      final root = await _ensureCacheRoot();
      final file = File('$root/${_cacheRelPath(bookId, ch, page)}');
      await file.create(recursive: true);
      await file.writeAsBytes(data);
    } catch (e) {
      debugPrint('SmartTtsEngine: disk cache write failed: $e');
    }
  }

  // ── Playback ───────────────────────────────────────────────────────

  Future<String> _saveTempWav(Uint8List wavBytes) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(wavBytes);
    return path;
  }

  Future<void> _playWav(Uint8List wavBytes, String text) async {
    final path = await _saveTempWav(wavBytes);
    final duration = await _player.setFilePath(path);
    if (duration == null) return;

    _activeAlignments = _calculateAlignments(text, duration);
    _isSpeaking = true;

    await _positionSubscription?.cancel();
    _positionSubscription = _player.positionStream.listen((pos) {
      _emitHighlightAtPosition(pos);
    });

    _player.processingStateStream
        .firstWhere((state) => state == ProcessingState.completed)
        .then((_) {
          _isSpeaking = false;
          _highlightController.add(null);
        }).catchError((_) {});

    await _player.play();
  }

  // ── Audio helpers ──────────────────────────────────────────────────

  /// Convert float PCM samples [-1, 1] to a 16-bit mono WAV byte array.
  static Uint8List _pcmToWav(List<double> samples, int sampleRate) {
    final dataSize = samples.length * 2;
    final buffer = ByteData(44 + dataSize);
    int o = 0;

    void w8(int v) {
      buffer.setUint8(o, v);
      o += 1;
    }

    void w16(int v) {
      buffer.setUint16(o, v, Endian.little);
      o += 2;
    }

    void w32(int v) {
      buffer.setUint32(o, v, Endian.little);
      o += 4;
    }

    w8(0x52);
    w8(0x49);
    w8(0x46);
    w8(0x46); // RIFF
    w32(36 + dataSize); // file size - 8
    w8(0x57);
    w8(0x41);
    w8(0x56);
    w8(0x45); // WAVE
    w8(0x66);
    w8(0x6D);
    w8(0x74);
    w8(0x20); // fmt_
    w32(16); // chunk size
    w16(1); // PCM
    w16(1); // mono
    w32(sampleRate);
    w32(sampleRate * 2); // byte rate
    w16(2); // block align
    w16(16); // bits per sample
    w8(0x64);
    w8(0x61);
    w8(0x74);
    w8(0x61); // data
    w32(dataSize);

    for (final sample in samples) {
      final intSample = (sample * 32767).clamp(-32768, 32767).toInt();
      buffer.setInt16(o, intSample, Endian.little);
      o += 2;
    }

    return buffer.buffer.asUint8List();
  }

  // ── Word alignment (proportional) ──────────────────────────────────

  void _emitHighlightAtPosition(Duration pos) {
    TtsWordAlignment? activeWord;
    for (final alignment in _activeAlignments) {
      if (pos >= alignment.startTime && pos < alignment.endTime) {
        activeWord = alignment;
        break;
      }
    }
    if (activeWord != null) {
      _highlightController.add(
        TtsWordHighlight(activeWord.startCharOffset, activeWord.endCharOffset),
      );
    } else {
      _highlightController.add(null);
    }
  }

  List<TtsWordAlignment> _calculateAlignments(
    String text,
    Duration totalDuration,
  ) {
    final words = <_WordInfo>[];
    final regex = RegExp(r'\S+');
    final matches = regex.allMatches(text);

    double totalWeight = 0;
    for (final match in matches) {
      final word = match.group(0)!;
      final start = match.start;
      final end = match.end;
      double weight = word.length.toDouble();
      if (word.endsWith('.') ||
          word.endsWith(',') ||
          word.endsWith('?') ||
          word.endsWith('!')) {
        weight += 2.0;
      }
      words.add(_WordInfo(word, start, end, weight));
      totalWeight += weight;
    }

    final alignments = <TtsWordAlignment>[];
    if (words.isEmpty || totalWeight == 0) return alignments;

    double currentMs = 0;
    final totalMs = totalDuration.inMilliseconds.toDouble();

    for (final w in words) {
      final durationMs = totalMs * (w.weight / totalWeight);
      final startTime = Duration(milliseconds: currentMs.toInt());
      currentMs += durationMs;
      final endTime = Duration(milliseconds: currentMs.toInt());
      alignments.add(
        TtsWordAlignment(
          word: w.word,
          startCharOffset: w.start,
          endCharOffset: w.end,
          startTime: startTime,
          endTime: endTime,
        ),
      );
    }
    return alignments;
  }
}

class _WordInfo {
  final String word;
  final int start;
  final int end;
  final double weight;
  _WordInfo(this.word, this.start, this.end, this.weight);
}
