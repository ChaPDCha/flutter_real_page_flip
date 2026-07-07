import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.chapdcha.real_page_flip/haptics');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AdvancedHapticEngine', () {
    group('playTransient', () {
      test('sends method call with correct name', () async {
        String? capturedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedMethod = call.method;
          return null;
        });

        await AdvancedHapticEngine.playTransient(
          intensity: 0.5,
          sharpness: 0.5,
          durationMs: 8,
        );

        expect(capturedMethod, 'playTransient');
      });

      test('clamps intensity to 0.0-1.0', () async {
        Map<dynamic, dynamic>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedArgs = call.arguments as Map<dynamic, dynamic>;
          return null;
        });

        // Above max
        await AdvancedHapticEngine.playTransient(
          intensity: 1.5,
          sharpness: 0.5,
          durationMs: 8,
        );
        expect(capturedArgs!['intensity'], 1.0);

        // Below min
        capturedArgs = null;
        await AdvancedHapticEngine.playTransient(
          intensity: -0.5,
          sharpness: 0.5,
          durationMs: 8,
        );
        expect(capturedArgs!['intensity'], 0.0);

        // Normal value passes through
        capturedArgs = null;
        await AdvancedHapticEngine.playTransient(
          intensity: 0.7,
          sharpness: 0.5,
          durationMs: 8,
        );
        expect(capturedArgs!['intensity'], 0.7);
      });

      test('clamps sharpness to 0.0-1.0', () async {
        Map<dynamic, dynamic>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedArgs = call.arguments as Map<dynamic, dynamic>;
          return null;
        });

        // Above max
        await AdvancedHapticEngine.playTransient(
          intensity: 0.5,
          sharpness: 1.5,
          durationMs: 8,
        );
        expect(capturedArgs!['sharpness'], 1.0);

        // Below min
        capturedArgs = null;
        await AdvancedHapticEngine.playTransient(
          intensity: 0.5,
          sharpness: -0.5,
          durationMs: 8,
        );
        expect(capturedArgs!['sharpness'], 0.0);

        // Normal value passes through
        capturedArgs = null;
        await AdvancedHapticEngine.playTransient(
          intensity: 0.5,
          sharpness: 0.3,
          durationMs: 8,
        );
        expect(capturedArgs!['sharpness'], 0.3);
      });

      test(
        'falls back to HapticFeedback when PlatformException is thrown',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playTransient(
            intensity: 0.5,
            sharpness: 0.5,
            durationMs: 8,
          );
        },
      );

      test('does not crash when handler returns null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);

        await AdvancedHapticEngine.playTransient(
          intensity: 0.5,
          sharpness: 0.5,
          durationMs: 8,
        );
      });
    });

    group('playThud', () {
      test('sends method call with correct name', () async {
        String? capturedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedMethod = call.method;
          return null;
        });

        await AdvancedHapticEngine.playThud(intensity: 0.5);

        expect(capturedMethod, 'playThud');
      });

      test('clamps intensity to 0.0-1.0', () async {
        Map<dynamic, dynamic>? capturedArgs;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedArgs = call.arguments as Map<dynamic, dynamic>;
          return null;
        });

        // Above max
        await AdvancedHapticEngine.playThud(intensity: 2);
        expect(capturedArgs!['intensity'], 1.0);

        // Below min
        capturedArgs = null;
        await AdvancedHapticEngine.playThud(intensity: -1);
        expect(capturedArgs!['intensity'], 0.0);

        // Normal value passes through
        capturedArgs = null;
        await AdvancedHapticEngine.playThud(intensity: 0.75);
        expect(capturedArgs!['intensity'], 0.75);
      });

      test(
        'falls back to HapticFeedback when PlatformException is thrown',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playThud(intensity: 0.5);
        },
      );
    });

    group('playSystemMedium', () {
      test('sends method call with correct name', () async {
        String? capturedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedMethod = call.method;
          return null;
        });

        await AdvancedHapticEngine.playSystemMedium();

        expect(capturedMethod, 'playSystemMedium');
      });

      test(
        'falls back to HapticFeedback when PlatformException is thrown',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playSystemMedium();
        },
      );

      test('does not throw when channel responds normally', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);

        await AdvancedHapticEngine.playSystemMedium();
      });
    });

    group('playSystemLight', () {
      test('sends method call with correct name', () async {
        String? capturedMethod;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
          capturedMethod = call.method;
          return null;
        });

        await AdvancedHapticEngine.playSystemLight();

        expect(capturedMethod, 'playSystemLight');
      });

      test(
        'falls back to HapticFeedback when PlatformException is thrown',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playSystemLight();
        },
      );

      test('does not throw when channel responds normally', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async => null);

        await AdvancedHapticEngine.playSystemLight();
      });
    });

    group('fallback behavior', () {
      test(
        'playTransient fallback uses mediumImpact when intensity > 0.6',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playTransient(
            intensity: 0.8,
            sharpness: 0.5,
            durationMs: 8,
          );
        },
      );

      test(
        'playTransient fallback uses lightImpact when intensity <= 0.6',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playTransient(
            intensity: 0.3,
            sharpness: 0.5,
            durationMs: 8,
          );
        },
      );

      test(
        'playTransient fallback uses lightImpact at boundary intensity 0.6',
        () async {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'test_error');
          });

          await AdvancedHapticEngine.playTransient(
            intensity: 0.6,
            sharpness: 0.5,
            durationMs: 8,
          );
        },
      );
    });
  });
}
