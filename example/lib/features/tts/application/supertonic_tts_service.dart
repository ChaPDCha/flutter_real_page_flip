import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sdk/helper.dart'; // Supertonic SDK helper
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class TtsWordHighlight {
  final int startOffset;
  final int endOffset;
  TtsWordHighlight(this.startOffset, this.endOffset);
}

class TtsSynthesisResult {
  final List<double> pcmSamples;
  final int sampleRate;
  TtsSynthesisResult({required this.pcmSamples, required this.sampleRate});
}

class TtsWordAlignment {
  final String word;
  final int startCharOffset;
  final int endCharOffset;
  final Duration startTime;
  final Duration endTime;

  TtsWordAlignment({
    required this.word,
    required this.startCharOffset,
    required this.endCharOffset,
    required this.startTime,
    required this.endTime,
  });
}

class SupertonicTtsService {
  final AudioPlayer _audioPlayer;
  TextToSpeech? _textToSpeech;
  Style? _style;
  bool _isInitialized = false;
  bool _isSpeaking = false;

  final _highlightController = StreamController<TtsWordHighlight?>.broadcast();
  Stream<TtsWordHighlight?> get highlightStream => _highlightController.stream;

  List<TtsWordAlignment> _activeAlignments = [];
  StreamSubscription? _positionSubscription;
  String? _lastOutputPath;

  SupertonicTtsService({AudioPlayer? audioPlayer})
    : _audioPlayer = audioPlayer ?? AudioPlayer();

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;

  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Synthesizes [text] to raw PCM audio without playing it.
  ///
  /// Returns the sample data and sample rate so callers can cache, encode,
  /// or stream the audio themselves. Throws if TTS models are not loaded.
  Future<TtsSynthesisResult> synthesize(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    if (!_isInitialized) {
      await init();
    }
    if (_textToSpeech == null || _style == null) {
      throw Exception('Supertonic TTS models not loaded');
    }

    final result = await _textToSpeech!.call(
      text,
      language,
      _style!,
      8,
      speed: speed,
    );
    final List<double> wav = result['wav'] is List<double>
        ? result['wav']
        : (result['wav'] as List).cast<double>();

    return TtsSynthesisResult(
      pcmSamples: wav,
      sampleRate: _textToSpeech!.sampleRate,
    );
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _textToSpeech = await loadTextToSpeech('assets/onnx', useGpu: false);
      _style = await loadVoiceStyle(['assets/voice_styles/M1.json']);
      _isInitialized = true;
      debugPrint('Supertonic TTS initialized successfully.');
    } catch (e) {
      debugPrint('Failed to initialize Supertonic TTS: $e');
      rethrow;
    }
  }

  Future<void> speak(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    if (!_isInitialized) {
      try {
        await init();
      } catch (e) {
        // Fallback simulation mode for testing or mock environment
        debugPrint(
          'Fallback mode: Assets missing, simulation activated. Text: $text',
        );
        _isSpeaking = true;
        _activeAlignments = _calculateAlignments(
          text,
          const Duration(seconds: 4),
        );
        await _positionSubscription?.cancel();

        // Emulate position ticks for fallback/testing
        int ticks = 0;
        _positionSubscription =
            Stream.periodic(const Duration(milliseconds: 100))
                .take(40)
                .listen(
                  (_) {
                    ticks += 100;
                    final pos = Duration(milliseconds: ticks);
                    _emitHighlightAtPosition(pos);
                  },
                  onDone: () {
                    _highlightController.add(null);
                    _isSpeaking = false;
                  },
                );
        return;
      }
    }

    if (_textToSpeech == null || _style == null) {
      throw Exception('Supertonic TTS models not loaded');
    }

    try {
      _isSpeaking = true;
      final result = await _textToSpeech!.call(
        text,
        language,
        _style!,
        8,
        speed: speed,
      );

      final List<double> wav = result['wav'] is List<double>
          ? result['wav']
          : (result['wav'] as List).cast<double>();

      // Clean up previous WAV file to avoid temp file accumulation
      if (_lastOutputPath != null) {
        try {
          await File(_lastOutputPath!).delete();
        } catch (_) {
          // Previous file may already be deleted or in use
        }
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '${tempDir.path}/speech_$timestamp.wav';
      _lastOutputPath = outputPath;

      writeWavFile(outputPath, wav, _textToSpeech!.sampleRate);

      final duration = await _audioPlayer.setFilePath(outputPath);
      final resolvedDuration =
          duration ?? Duration(milliseconds: text.length * 150);

      _activeAlignments = _calculateAlignments(text, resolvedDuration);

      await _audioPlayer.play();
      await _positionSubscription?.cancel();

      _positionSubscription = _audioPlayer.positionStream.listen((pos) {
        _emitHighlightAtPosition(pos);
      });
    } catch (e) {
      debugPrint('Error synthesizing speech: $e');
      _isSpeaking = false;
      rethrow;
    }
  }

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
      final double durationMs = totalMs * (w.weight / totalWeight);
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

  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  Future<void> resume() async {
    await _audioPlayer.play();
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _highlightController.add(null);
    await _audioPlayer.stop();
    _isSpeaking = false;

    // Clean up the last WAV temp file
    if (_lastOutputPath != null) {
      try {
        await File(_lastOutputPath!).delete();
      } catch (_) {
        // File may already be deleted or in use
      }
      _lastOutputPath = null;
    }
  }

  void dispose() {
    _positionSubscription?.cancel();
    _highlightController.close();
    _audioPlayer.dispose();
  }
}

class _WordInfo {
  final String word;
  final int start;
  final int end;
  final double weight;
  _WordInfo(this.word, this.start, this.end, this.weight);
}
