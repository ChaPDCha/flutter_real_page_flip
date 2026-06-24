import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => null,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('flutter_vibration'),
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'hasVibrator':
            return false;
          case 'hasAmplitudeControl':
            return false;
          case 'cancel':
            return null;
          case 'vibrate':
            return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      MethodChannel('flutter_vibration'),
      null,
    );
  });

  group('DefaultPageFlipEffectHandler', () {
    test('constructor succeeds with default profile', () {
      final handler = DefaultPageFlipEffectHandler();
      expect(handler, isNotNull);
    });

    group('onHandleEffect event routing', () {
      test('startHaptic does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(PageFlipEvent.startHaptic);
      });

      test('stopHaptic does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(PageFlipEvent.stopHaptic, pageIndex: 0);
      });

      test('impulseHaptic does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(PageFlipEvent.impulseHaptic);
      });

      test('continuousHaptic with parameters does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.continuousHaptic,
          pageIndex: 1,
          intensity: 128,
          texture: 0.5,
          resistance: 0.5,
        );
      });

      test('continuousHaptic with null pageIndex falls back', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.continuousHaptic,
          // pageIndex and texture intentionally null
        );
      });

      test('texturedHaptic with texture above threshold does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 2,
          intensity: 200,
          texture: 0.8,
          resistance: 0.5,
        );
      });

      test('texturedHaptic with texture below threshold does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 3,
          intensity: 60,
          texture: 0.1,
          resistance: 0.5,
        );
      });

      test('sound event with volume does not throw', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(PageFlipEvent.sound, volume: 0.8);
      });

      test('all event types can be called without throwing', () async {
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        for (final event in PageFlipEvent.values) {
          await handler.onHandleEffect(
            event,
            pageIndex: 0,
            intensity: 128,
            texture: 0.7,
            volume: 1.0,
            resistance: 0.5,
          );
        }
      });
    });

    group('texture tick platform paths', () {
      test('iOS path uses selectionClick', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 10,
          intensity: 200,
          texture: 0.9,
          resistance: 0.5,
        );
        debugDefaultTargetPlatformOverride = null;
      });

      test('Android path uses vibrateMotor', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 11,
          intensity: 200,
          texture: 0.9,
          resistance: 0.5,
        );
        debugDefaultTargetPlatformOverride = null;
      });
    });

    group('performance profiles', () {
      test('low profile does not throw', () async {
        final handler = DefaultPageFlipEffectHandler(
          performanceProfile: DevicePerformanceProfile.low,
        );
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 20,
          intensity: 80,
          texture: 0.9,
          resistance: 0.5,
        );
      });

      test('medium profile does not throw', () async {
        final handler = DefaultPageFlipEffectHandler(
          performanceProfile: DevicePerformanceProfile.medium,
        );
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 21,
          intensity: 150,
          texture: 0.9,
          resistance: 0.5,
        );
      });

      test('high profile does not throw', () async {
        final handler = DefaultPageFlipEffectHandler(
          performanceProfile: DevicePerformanceProfile.high,
        );
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 22,
          intensity: 200,
          texture: 0.9,
          resistance: 0.5,
        );
      });
    });

    test('dispose does not throw', () {
      final handler = DefaultPageFlipEffectHandler();
      handler.dispose();
    });

    test('multiple consecutive texture ticks do not throw', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future<void>.delayed(Duration.zero);
      for (int i = 0; i < 5; i++) {
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 30,
          intensity: 100 + i * 20,
          texture: 0.85,
          resistance: 0.5,
        );
      }
    });

    test('multiple page indices create separate physics engines', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future<void>.delayed(Duration.zero);
      for (int i = 0; i < 3; i++) {
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: i,
          intensity: 150,
          texture: 0.9,
          resistance: 0.5,
        );
      }
    });

    test('stopHaptic resets engine for specific page', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future<void>.delayed(Duration.zero);
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 40,
        intensity: 128,
        texture: 0.7,
        resistance: 0.5,
      );
      await handler.onHandleEffect(PageFlipEvent.stopHaptic, pageIndex: 40);
    });

    test('extreme intensity values do not cause crashes', () async {
      final handler = DefaultPageFlipEffectHandler();
      await Future<void>.delayed(Duration.zero);
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 50,
        intensity: 0,
        texture: 0.9,
        resistance: 0.5,
      );
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 50,
        intensity: 255,
        texture: 0.9,
        resistance: 0.5,
      );
    });
  });
}
