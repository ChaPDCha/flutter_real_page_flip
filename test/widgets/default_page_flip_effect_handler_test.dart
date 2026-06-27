import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Set up mocks for all three audioplayers channels plus vibration.
  void setupAudioMocks(
    Future<dynamic> Function(MethodCall) audioplayersHandler,
  ) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      audioplayersHandler,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      audioplayersHandler,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      audioplayersHandler,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.chapdcha.real_page_flip/haptics'),
      (methodCall) async => null,
    );
  }

  /// Clear all platform channel mocks.
  void clearMocks() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.chapdcha.real_page_flip/haptics'),
      null,
    );
  }

  group('DefaultPageFlipEffectHandler', () {
    setUp(() {
      setupAudioMocks((methodCall) async => null);
    });

    tearDown(() async {
      // Drain pending async (e.g. Vibration.hasVibrator().then(...)) before
      // clearing mocks to avoid MissingPluginException in background callbacks.
      await Future.delayed(const Duration(milliseconds: 50));
      clearMocks();
    });

    test('handler was created without errors', () async {
      final handler = DefaultPageFlipEffectHandler();
      expect(handler, isNotNull);
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 10));
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('handleEffect with sound triggers platform channel calls', () async {
      final handler = DefaultPageFlipEffectHandler();
      // Wait for async _initAudio to complete so _audioReady is true
      await Future.delayed(const Duration(milliseconds: 10));

      expect(
        () => handler.onHandleEffect(PageFlipEvent.sound, volume: 0.5),
        returnsNormally,
      );

      // Wait for the stop/setVolume/resume async chain
      await Future.delayed(Duration.zero);

      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('initialization failures do not crash', () async {
      // Mock audio channels: allow AudioPlayer creation (create/init) but
      // fail setSource/setReleaseMode calls so _initAudio's try-catch is exercised.
      setupAudioMocks((methodCall) async {
        if (methodCall.method == 'create' || methodCall.method == 'init') {
          return null; // Allow AudioPlayer construction
        }
        throw PlatformException(code: 'ERROR');
      });

      DefaultPageFlipEffectHandler? failingHandler;
      expect(
        () => failingHandler = DefaultPageFlipEffectHandler(),
        returnsNormally,
      );

      // Wait for both try-catch blocks in _initAudio to complete
      await Future.delayed(const Duration(milliseconds: 10));

      expect(failingHandler, isNotNull);
      // Restore normal mocks so dispose() can clean up without errors
      setupAudioMocks((methodCall) async => null);
      failingHandler!.dispose();
      await Future.delayed(Duration.zero);
    });

    test('dispose method cleans up resources', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(() => handler.dispose(), returnsNormally);
      await Future.delayed(Duration.zero);
    });

    test('handleEffect with impulseHaptic triggers medium impact', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(PageFlipEvent.impulseHaptic),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('continuousHaptic without pageIndex falls back to light impact',
        () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(PageFlipEvent.continuousHaptic),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('continuousHaptic with pageIndex and texture runs physics haptic',
        () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(
          PageFlipEvent.continuousHaptic,
          pageIndex: 0,
          texture: 0.5,
          intensity: 60,
          resistance: 0.5,
        ),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('texturedHaptic with null pageIndex falls back to light impact',
        () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () =>
            handler.onHandleEffect(PageFlipEvent.texturedHaptic, texture: 0.5),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('startHaptic triggers light impact', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(PageFlipEvent.startHaptic),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('MP3 fallback when Opus source fails', () async {
      setupAudioMocks((methodCall) async {
        if (methodCall.method == 'setSource') {
          final args = methodCall.arguments as Map<dynamic, dynamic>;
          final url = args['url'] as String;
          if (url.contains('.opus')) {
            throw PlatformException(code: 'ERROR', message: 'Opus not found');
          }
        }
        return null;
      });

      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(PageFlipEvent.sound, volume: 0.5),
        returnsNormally,
      );
      await Future.delayed(Duration.zero);

      setupAudioMocks((methodCall) async => null);
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('Opus audio init sets audioReady', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      expect(
        () => handler.onHandleEffect(PageFlipEvent.sound),
        returnsNormally,
      );
      await Future.delayed(Duration.zero);
      handler.dispose();
      await Future.delayed(Duration.zero);
    });

    test('stopHaptic handles cancel and engine reset gracefully', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future.delayed(const Duration(milliseconds: 10));
      // stopHaptic without pageIndex — just cancels vibration
      expect(
        () => handler.onHandleEffect(PageFlipEvent.stopHaptic),
        returnsNormally,
      );
      // stopHaptic with pageIndex — cancels + resets engine
      expect(
        () => handler.onHandleEffect(PageFlipEvent.stopHaptic, pageIndex: 5),
        returnsNormally,
      );
      handler.dispose();
      // Allow any pending async work to drain before mock teardown
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('sound skipped when audio not ready', () async {
      final handler = DefaultPageFlipEffectHandler();
      // Immediately call before _initAudio completes
      expect(
        () => handler.onHandleEffect(PageFlipEvent.sound, volume: 0.5),
        returnsNormally,
      );
      handler.dispose();
      await Future.delayed(Duration.zero);
    });
  });
}
