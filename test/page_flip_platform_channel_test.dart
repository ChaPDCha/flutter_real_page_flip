import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/models/advanced_haptic_engine.dart';
import 'utils/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const hapticChannel = MethodChannel('com.chapdcha.real_page_flip/haptics');

  setUp(() {
    setupHapticMock();
  });

  tearDown(() {
    clearAllChannelMocks();
  });

  group('AdvancedHapticEngine platform channel', () {
    test('playTransient sends intensity and sharpness', () async {
      List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (call) async {
        calls.add(call);
        return null;
      });

      await AdvancedHapticEngine.playTransient(
        intensity: 0.7,
        sharpness: 0.3,
      );

      expect(calls, hasLength(1));
      expect(calls[0].method, 'playTransient');
      expect(calls[0].arguments['intensity'], closeTo(0.7, 1e-6));
      expect(calls[0].arguments['sharpness'], closeTo(0.3, 1e-6));
    });

    test('playTransient clamps intensity to [0, 1]', () async {
      List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (call) async {
        calls.add(call);
        return null;
      });

      await AdvancedHapticEngine.playTransient(
        intensity: 5.0,
        sharpness: -1.0,
      );

      expect(calls, hasLength(1));
      expect(calls[0].arguments['intensity'], closeTo(1.0, 1e-6));
      expect(calls[0].arguments['sharpness'], closeTo(0.0, 1e-6));
    });

    test('playThud sends intensity', () async {
      List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (call) async {
        calls.add(call);
        return null;
      });

      await AdvancedHapticEngine.playThud(intensity: 0.8);

      expect(calls, hasLength(1));
      expect(calls[0].method, 'playThud');
      expect(calls[0].arguments['intensity'], closeTo(0.8, 1e-6));
    });

    test('playSystemMedium sends method call', () async {
      List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (call) async {
        calls.add(call);
        return null;
      });

      await AdvancedHapticEngine.playSystemMedium();

      expect(calls, hasLength(1));
      expect(calls[0].method, 'playSystemMedium');
    });

    test('playSystemLight sends method call', () async {
      List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (call) async {
        calls.add(call);
        return null;
      });

      await AdvancedHapticEngine.playSystemLight();

      expect(calls, hasLength(1));
      expect(calls[0].method, 'playSystemLight');
    });

    test('playTransient PlatformException falls back to system haptic',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (_) async {
        throw PlatformException(code: 'ERROR');
      });

      // Should not throw despite platform error
      await AdvancedHapticEngine.playTransient(
        intensity: 0.7,
        sharpness: 0.5,
      );
      // If we get here without exception, the fallback worked
    });

    test('playThud PlatformException falls back gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (_) async {
        throw PlatformException(code: 'ERROR');
      });

      await AdvancedHapticEngine.playThud(intensity: 0.5);
    });

    test('playSystemMedium PlatformException falls back gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (_) async {
        throw PlatformException(code: 'ERROR');
      });

      await AdvancedHapticEngine.playSystemMedium();
    });

    test('playSystemLight PlatformException falls back gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(hapticChannel, (_) async {
        throw PlatformException(code: 'ERROR');
      });

      await AdvancedHapticEngine.playSystemLight();
    });
  });
}
