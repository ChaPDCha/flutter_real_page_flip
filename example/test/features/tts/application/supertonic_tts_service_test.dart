import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_service.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SupertonicTtsService Tests', () {
    late SupertonicTtsService ttsService;
    late MockAudioPlayer mockAudioPlayer;

    setUp(() {
      mockAudioPlayer = MockAudioPlayer();

      // Mock audio player methods to avoid hanging on native platform channels
      when(() => mockAudioPlayer.playerStateStream).thenAnswer((_) => const Stream<PlayerState>.empty());
      when(() => mockAudioPlayer.pause()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.play()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.stop()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      when(() => mockAudioPlayer.setFilePath(any())).thenAnswer((_) async => null);

      ttsService = SupertonicTtsService(audioPlayer: mockAudioPlayer);
    });

    tearDown(() {
      ttsService.dispose();
    });

    test('Initial state: not initialized and not speaking', () {
      expect(ttsService.isInitialized, isFalse);
      expect(ttsService.isSpeaking, isFalse);
    });

    test('init() throws since assets are missing in test context', () async {
      expect(ttsService.init(), throwsA(anything));
      expect(ttsService.isInitialized, isFalse);
    });

    test('speak() falls back gracefully when init fails (no crash)', () async {
      // Since assets/onnx doesn't exist/work in test, speak should hit the fallback try-catch
      // and print fallback message without throwing.
      await expectLater(
        ttsService.speak('테스트 문장입니다.'),
        completes,
      );
      expect(ttsService.isSpeaking, isTrue);
    });

    test('pause, resume, and stop delegate to AudioPlayer without crash', () async {
      await expectLater(ttsService.pause(), completes);
      await expectLater(ttsService.resume(), completes);
      await expectLater(ttsService.stop(), completes);
      expect(ttsService.isSpeaking, isFalse);

      verify(() => mockAudioPlayer.pause()).called(1);
      verify(() => mockAudioPlayer.play()).called(1);
      verify(() => mockAudioPlayer.stop()).called(1);
    });
  });
}
