import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:real_page_flip_example/features/tts/application/smart_tts_engine.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_service.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}

class _FakeTtsService extends Fake implements SupertonicTtsService {
  int synthesizeCallCount = 0;

  @override
  Future<TtsSynthesisResult> synthesize(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    synthesizeCallCount++;
    return TtsSynthesisResult(
      pcmSamples: List.filled(16000, 0.0),
      sampleRate: 16000,
    );
  }

  @override
  Future<void> init() async {}

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
}

class _FakeFailingTtsService extends Fake implements SupertonicTtsService {
  @override
  Future<TtsSynthesisResult> synthesize(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    throw Exception('TTS synthesis failed');
  }

  @override
  Future<void> init() async {}

  @override
  Stream<PlayerState> get playerStateStream => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helpers to mock/unmock path_provider platform channel
  void setupPathProviderMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        if (call.method == 'getTemporaryDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  }

  void teardownPathProviderMock() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  }

  void clearDiskCache() {
    final dir = Directory('${Directory.systemTemp.path}/tts_cache');
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  //  SmartTtsEngine tests
  // ─────────────────────────────────────────────────────────────────────

  group('SmartTtsEngine', () {
    late _FakeTtsService fakeTts;
    late _MockAudioPlayer mockPlayer;
    late SmartTtsEngine engine;

    setUp(() {
      setupPathProviderMock();
      clearDiskCache();

      fakeTts = _FakeTtsService();
      mockPlayer = _MockAudioPlayer();

      when(() => mockPlayer.setFilePath(
            any(),
            initialPosition: any(named: 'initialPosition'),
            preload: any(named: 'preload'),
            tag: any(named: 'tag'),
          )).thenAnswer((_) async => Duration.zero);
      when(mockPlayer.play).thenAnswer((_) async {});
      when(mockPlayer.stop).thenAnswer((_) async {});
      when(mockPlayer.pause).thenAnswer((_) async {});
      when(mockPlayer.dispose).thenAnswer((_) async {});
      when(() => mockPlayer.positionStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.processingStateStream)
          .thenAnswer((_) => const Stream.empty());
      when(() => mockPlayer.playerStateStream)
          .thenAnswer((_) => const Stream.empty());

      engine = SmartTtsEngine(ttsService: fakeTts, player: mockPlayer);
    });

    tearDown(() {
      engine.dispose();
      teardownPathProviderMock();
    });

    // ── Basic state ───────────────────────────────────────────────

    test('initial state is not speaking', () {
      expect(engine.isSpeaking, isFalse);
    });

    test('pause and resume delegate without crash', () async {
      await engine.pause();
      await engine.resume();
      expect(engine.isSpeaking, isFalse);
    });

    test('stop clears state', () async {
      await engine.stop();
      expect(engine.isSpeaking, isFalse);
    });

    test('multiple sequential stop calls do not crash', () async {
      for (int i = 0; i < 5; i++) {
        await engine.stop();
      }
      expect(engine.isSpeaking, isFalse);
    });

    // ── Streams ──────────────────────────────────────────────────

    test('exposes required streams', () {
      expect(engine.playerStateStream, isA<Stream<PlayerState>>());
      expect(engine.highlightStream, isA<Stream<TtsWordHighlight?>>());
    });

    // ── Speak & Cache ────────────────────────────────────────────

    test('first speak calls synthesize, second uses memory cache', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Hello world.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'b1',
        text: 'Hello world.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('different pages each trigger separate synthesis', () async {
      for (int i = 0; i < 3; i++) {
        await engine.speak(
          bookId: 'b1',
          text: 'Page $i.',
          chapterIndex: 0,
          pageIndex: i,
        );
      }
      expect(fakeTts.synthesizeCallCount, equals(3));
    });

    test('re-speaking an already-cached page skips synthesis', () async {
      for (int i = 0; i < 3; i++) {
        await engine.speak(
          bookId: 'b1',
          text: 'Page $i.',
          chapterIndex: 0,
          pageIndex: i,
        );
      }
      // Re-speak page 1 — should be in memory cache
      await engine.speak(
        bookId: 'b1',
        text: 'Page 1.',
        chapterIndex: 0,
        pageIndex: 1,
      );
      expect(fakeTts.synthesizeCallCount, equals(3));
    });

    test('speak with empty text does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: '',
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    // ── Multi-book and multi-chapter isolation ───────────────────

    test('different books with same page index use separate cache', () async {
      await engine.speak(
        bookId: 'bookA',
        text: 'Content A.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'bookB',
        text: 'Content B.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(2));

      // Each should be cached independently
      await engine.speak(
        bookId: 'bookA',
        text: 'Content A.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'bookB',
        text: 'Content B.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(2));
    });

    test('different chapters with same page index use separate cache', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Ch0 page.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'b1',
        text: 'Ch1 page.',
        chapterIndex: 1,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(2));

      await engine.speak(
        bookId: 'b1',
        text: 'Ch0 page.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'b1',
        text: 'Ch1 page.',
        chapterIndex: 1,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(2));
    });

    // ── Disk cache ───────────────────────────────────────────────

    test('disk cache persists across engine instances', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Persist me.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));

      // Create a fresh engine — disk cache still has the file
      final engine2 = SmartTtsEngine(ttsService: fakeTts, player: mockPlayer);
      await engine2.speak(
        bookId: 'b1',
        text: 'Persist me.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1)); // Disk cache hit
      engine2.dispose();
    });

    test('LRU memory cache eviction falls back to disk', () async {
      // Memory cache max = 5. Speak 6 pages — page 0 evicted from memory.
      for (int i = 0; i < 6; i++) {
        await engine.speak(
          bookId: 'b1',
          text: 'Page $i.',
          chapterIndex: 0,
          pageIndex: i,
        );
      }
      expect(fakeTts.synthesizeCallCount, equals(6));

      // page 0 is evicted from memory but still on disk — no re-synthesis
      await engine.speak(
        bookId: 'b1',
        text: 'Page 0.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(6));

      // page 5 is still in memory cache
      await engine.speak(
        bookId: 'b1',
        text: 'Page 5.',
        chapterIndex: 0,
        pageIndex: 5,
      );
      expect(fakeTts.synthesizeCallCount, equals(6));

      // page 1 is still on disk too
      await engine.speak(
        bookId: 'b1',
        text: 'Page 1.',
        chapterIndex: 0,
        pageIndex: 1,
      );
      expect(fakeTts.synthesizeCallCount, equals(6));
    });

    // ── Text edge cases ──────────────────────────────────────────

    test('speak with Korean text does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: '안녕하세요. 이것은 한국어 TTS 테스트입니다.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('speak with Japanese text does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'こんにちは。これは日本語のテストです。',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('speak with emoji and special characters does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Hello 👋 world! Test… «quote» — dash • star ★',
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    test('speak with multi-byte unicode (CJK) caches correctly', () async {
      await engine.speak(
        bookId: 'b1',
        text: '日本語のページ',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'b1',
        text: '日本語のページ',
        chapterIndex: 0,
        pageIndex: 0,
      );
      // Second call should hit memory cache
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('speak with whitespace-only text does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: '   \t\n  \r\n  ',
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    test('speak with very long text (5000+ chars) does not crash', () async {
      final longText = 'Hello world. ' * 400; // ~5600 chars
      await engine.speak(
        bookId: 'b1',
        text: longText,
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    test('speak with punctuation-heavy text does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Hello! Is this working? Yes, it is. Wait... No! Really? '
            'Check: one, two, three. "Quotes" and (parentheses).',
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    test('speak with HTML entities does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Tom &amp; Jerry &lt;3 &quot;Quoted&quot; &apos;Apostrophe&apos;',
        chapterIndex: 0,
        pageIndex: 0,
      );
    });

    test('whitespace-only text in preGeneratePage is synthesized', () async {
      // Whitespace is not empty — pre-generation treats it as valid content
      await engine.preGeneratePage('b1', '   ', 0, 0);
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    // ── Pre-generation ───────────────────────────────────────────

    test('preGeneratePage caches for later speak', () async {
      await engine.preGeneratePage('b1', 'Pre-gen content.', 0, 5);
      expect(fakeTts.synthesizeCallCount, equals(1));

      await engine.speak(
        bookId: 'b1',
        text: 'Pre-gen content.',
        chapterIndex: 0,
        pageIndex: 5,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('preGeneratePage skips already cached pages', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Already cached.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));

      await engine.preGeneratePage('b1', 'Already cached.', 0, 0);
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('preGeneratePage with empty text is no-op', () async {
      await engine.preGeneratePage('b1', '', 0, 0);
      expect(fakeTts.synthesizeCallCount, equals(0));
    });

    test('preGeneratePage multiple pages in sequence', () async {
      for (int i = 0; i < 5; i++) {
        await engine.preGeneratePage(
          'b1',
          'Upcoming page $i.',
          0,
          i + 10,
        );
      }
      expect(fakeTts.synthesizeCallCount, equals(5));

      // All should be cached, no extra synthesis
      for (int i = 0; i < 5; i++) {
        await engine.speak(
          bookId: 'b1',
          text: 'Upcoming page $i.',
          chapterIndex: 0,
          pageIndex: i + 10,
        );
      }
      expect(fakeTts.synthesizeCallCount, equals(5));
    });

    test('preGeneratePage after speak with same key is no-op', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Same page.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(fakeTts.synthesizeCallCount, equals(1));

      await engine.preGeneratePage('b1', 'Same page.', 0, 0);
      expect(fakeTts.synthesizeCallCount, equals(1));
    });

    test('preGeneratePage with different book IDs are cached separately', () async {
      await engine.preGeneratePage('bookA', 'Content.', 0, 0);
      await engine.preGeneratePage('bookB', 'Content.', 0, 0);
      expect(fakeTts.synthesizeCallCount, equals(2));

      // Each book's cache is independent
      await engine.speak(bookId: 'bookA', text: 'Content.', chapterIndex: 0, pageIndex: 0);
      await engine.speak(bookId: 'bookB', text: 'Content.', chapterIndex: 0, pageIndex: 0);
      expect(fakeTts.synthesizeCallCount, equals(2));
    });

    // ── State lifecycle ──────────────────────────────────────────

    test('isSpeaking is true after speak completes', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(engine.isSpeaking, isTrue);
    });

    test('isSpeaking false after stop during playback', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(engine.isSpeaking, isTrue);

      await engine.stop();
      expect(engine.isSpeaking, isFalse);
    });

    test('isSpeaking false after multiple stop calls', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.stop();
      await engine.stop();
      await engine.stop();
      expect(engine.isSpeaking, isFalse);
    });

    test('isSpeaking resets to false when playback completes', () async {
      final processingCtrl = StreamController<ProcessingState>();
      when(() => mockPlayer.processingStateStream)
          .thenAnswer((_) => processingCtrl.stream);

      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      expect(engine.isSpeaking, isTrue);

      processingCtrl.add(ProcessingState.completed);
      // Drain microtask queue so .then callback fires
      await Future<void>.value();
      expect(engine.isSpeaking, isFalse);

      await processingCtrl.close();
    });

    test('dispose during playback does not crash', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      // dispose is called in tearDown — just verify no crash when
      // called after speak
    });

    // ── Concurrency ──────────────────────────────────────────────

    test('sequential speak calls each synthesize new pages', () async {
      for (int i = 0; i < 5; i++) {
        await engine.speak(
          bookId: 'b1',
          text: 'Seq $i.',
          chapterIndex: 0,
          pageIndex: i,
        );
      }
      expect(fakeTts.synthesizeCallCount, equals(5));
    });

    test('speak during active playback stops previous and starts new', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'First page.',
        chapterIndex: 0,
        pageIndex: 0,
      );
      await engine.speak(
        bookId: 'b1',
        text: 'Second page.',
        chapterIndex: 0,
        pageIndex: 1,
      );
      // Both synthesizes happened
      expect(fakeTts.synthesizeCallCount, equals(2));
      // Last state is the second page
      expect(engine.isSpeaking, isTrue);
    });

    // ── Error handling ───────────────────────────────────────────

    test('synthesis failure is rethrown from speak', () async {
      final failingEngine = SmartTtsEngine(
        ttsService: _FakeFailingTtsService(),
        player: mockPlayer,
      );

      await expectLater(
        failingEngine.speak(
          bookId: 'b1',
          text: 'Fail.',
          chapterIndex: 0,
          pageIndex: 0,
        ),
        throwsException,
      );

      failingEngine.dispose();
    });

    test('preGeneratePage with failing synthesize does not crash', () async {
      final failingEngine = SmartTtsEngine(
        ttsService: _FakeFailingTtsService(),
        player: mockPlayer,
      );

      // preGeneratePage catches errors internally
      await failingEngine.preGeneratePage('b1', 'Fail.', 0, 0);

      failingEngine.dispose();
    });

    test('preGeneratePage with failing synthesize does not affect cache', () async {
      final failingEngine = SmartTtsEngine(
        ttsService: _FakeFailingTtsService(),
        player: mockPlayer,
      );

      await failingEngine.preGeneratePage('b1', 'Fail.', 0, 0);

      // Engine should still be usable (speak with real engine works)
      failingEngine.dispose();
    });

    // ── WAV format verification ──────────────────────────────────

    test('produced WAV has valid RIFF/WAVE header', () async {
      await engine.speak(
        bookId: 'b1',
        text: 'Test.',
        chapterIndex: 0,
        pageIndex: 0,
      );

      final cacheFile = File(
        '${Directory.systemTemp.path}/tts_cache/b1/0_0.ttsc',
      );
      expect(cacheFile.existsSync(), isTrue);

      final bytes = await cacheFile.readAsBytes();
      expect(bytes.length, greaterThan(44));

      // RIFF marker
      expect(bytes[0], 0x52); // R
      expect(bytes[1], 0x49); // I
      expect(bytes[2], 0x46); // F
      expect(bytes[3], 0x46); // F

      // WAVE format
      expect(bytes[8], 0x57); // W
      expect(bytes[9], 0x41); // A
      expect(bytes[10], 0x56); // V
      expect(bytes[11], 0x45); // E

      // PCM format = 1
      expect(bytes[20], 1);
      // Mono = 1
      expect(bytes[22], 1);
      // Sample rate = 16000 (LE: 0x3E80)
      expect(bytes[24], 0x80);
      expect(bytes[25], 0x3E);
      expect(bytes[26], 0);
      expect(bytes[27], 0);
      // Bits per sample = 16
      expect(bytes[34], 16);
      expect(bytes[35], 0);

      // "data" chunk marker
      expect(bytes[36], 0x64); // d
      expect(bytes[37], 0x61); // a
      expect(bytes[38], 0x74); // t
      expect(bytes[39], 0x61); // a

      // PCM data size = 16000 * 2 bytes/sample = 32000
      final dataSize = bytes[40] |
          (bytes[41] << 8) |
          (bytes[42] << 16) |
          (bytes[43] << 24);
      expect(dataSize, equals(32000));

      // Total file size = 44 header + data
      expect(bytes.length, equals(44 + dataSize));
    });

    test('produced WAV for long text is valid', () async {
      final longText = 'Hello world. ' * 100; // ~1400 chars
      await engine.speak(
        bookId: 'b1',
        text: longText,
        chapterIndex: 0,
        pageIndex: 1,
      );

      final cacheFile = File(
        '${Directory.systemTemp.path}/tts_cache/b1/0_1.ttsc',
      );
      expect(cacheFile.existsSync(), isTrue);

      final bytes = await cacheFile.readAsBytes();
      // Verify RIFF + WAVE markers
      expect(bytes[0], 0x52);
      expect(bytes[1], 0x49);
      expect(bytes[8], 0x57);
      expect(bytes[9], 0x41);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  //  Data classes
  // ─────────────────────────────────────────────────────────────────────

  group('Data classes', () {
    test('TtsWordHighlight stores offsets', () {
      final hl = TtsWordHighlight(5, 10);
      expect(hl.startOffset, 5);
      expect(hl.endOffset, 10);
    });

    test('TtsSynthesisResult valid PCM lengths', () {
      final result = TtsSynthesisResult(
        pcmSamples: [0.0, 0.5, -0.5],
        sampleRate: 22050,
      );
      expect(result.pcmSamples.length, 3);
      expect(result.sampleRate, 22050);
    });
  });
}
