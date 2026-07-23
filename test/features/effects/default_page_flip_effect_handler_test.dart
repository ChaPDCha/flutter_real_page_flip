import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('flip sound volume remains quiet even for extreme input', () {
    expect(cappedFlipSoundVolume(0), 0.04);
    expect(cappedFlipSoundVolume(0.25), 0.1);
    expect(cappedFlipSoundVolume(0.55), 0.22);
    expect(cappedFlipSoundVolume(100), 0.22);
    expect(cappedFlipSoundVolume(double.nan), 0.04);
  });

  test('paper haptic levels have clearly separated output signatures', () {
    const activePresets = [
      PaperTexturePreset.smooth,
      PaperTexturePreset.standard,
      PaperTexturePreset.textured,
      PaperTexturePreset.kraft,
    ];
    final outputs = activePresets
        .map(
          (preset) => shapePaperHapticOutput(
            preset: preset,
            rawAmplitude: 0.5,
            rawSharpness: 0.5,
            speedFactor: 0.5,
          ),
        )
        .toList();

    for (var i = 1; i < outputs.length; i++) {
      expect(outputs[i].amplitude, greaterThan(outputs[i - 1].amplitude));
      expect(
        outputs[i].samplesPerGrain,
        greaterThan(outputs[i - 1].samplesPerGrain),
      );
      expect(outputs[i].sharpness, lessThan(outputs[i - 1].sharpness));
    }
  });

  test('none preset produces no haptic waveform samples', () {
    final output = shapePaperHapticOutput(
      preset: PaperTexturePreset.none,
      rawAmplitude: 1,
      rawSharpness: 1,
      speedFactor: 1,
    );

    expect(output.amplitude, 0);
    expect(output.sharpness, 0);
    expect(output.samplesPerGrain, 0);
  });

  test('settle and detent feedback scale across all four paper levels', () {
    const presets = [
      PaperTexturePreset.smooth,
      PaperTexturePreset.standard,
      PaperTexturePreset.textured,
      PaperTexturePreset.kraft,
    ];
    final settles = presets
        .map(
          (preset) => paperSettleIntensity(
            preset: preset,
            controllerIntensity: 60,
          ),
        )
        .toList();
    final detents = presets.map(paperDetentOutput).toList();

    for (var i = 1; i < presets.length; i++) {
      expect(settles[i], greaterThan(settles[i - 1]));
      expect(detents[i].intensity, greaterThan(detents[i - 1].intensity));
      expect(detents[i].durationMs, greaterThan(detents[i - 1].durationMs));
    }
    expect(
      paperSettleIntensity(
        preset: PaperTexturePreset.none,
        controllerIntensity: 120,
      ),
      0,
    );
  });

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => null,
    );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.chapdcha.real_page_flip/haptics'),
      (methodCall) async {
        if (methodCall.method == 'getHapticCapabilities') {
          return {
            'hasVibrator': true,
            'hasAmplitudeControl': true,
            'hasAdvancedHaptics': true,
          };
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.chapdcha.real_page_flip/haptics'),
      null,
    );
  });

  group('DefaultPageFlipEffectHandler', () {
    test('constructor succeeds with default profile', () {
      final handler = DefaultPageFlipEffectHandler();
      expect(handler, isNotNull);
    });

    test('none preset suppresses every haptic event', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.chapdcha.real_page_flip/haptics'),
        (call) async {
          calls.add(call);
          return null;
        },
      );
      final handler = DefaultPageFlipEffectHandler(
        hapticTexturePreset: PaperTexturePreset.none,
      );

      for (final event in [
        PageFlipEvent.startHaptic,
        PageFlipEvent.continuousHaptic,
        PageFlipEvent.texturedHaptic,
        PageFlipEvent.detentHaptic,
        PageFlipEvent.impulseHaptic,
        PageFlipEvent.stopHaptic,
      ]) {
        await handler.onHandleEffect(
          event,
          pageIndex: 0,
          intensity: 84,
          texture: 1,
          resistance: 1,
        );
      }

      expect(
        calls.where((call) => call.method != 'getHapticCapabilities'),
        isEmpty,
      );
      handler.dispose();
    });

    test('basic quality never emits a drag waveform', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.chapdcha.real_page_flip/haptics'),
        (call) async {
          calls.add(call);
          return {
            'hasVibrator': true,
            'hasAmplitudeControl': false,
            'hasAdvancedHaptics': false,
          };
        },
      );
      final handler = DefaultPageFlipEffectHandler(
        hapticQuality: HapticQuality.basic,
      );
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 0,
        intensity: 84,
        texture: 1,
        resistance: 1,
      );

      expect(
        calls.map((call) => call.method),
        isNot(contains('playContinuousWaveform')),
      );
      handler.dispose();
    });

    test('standard quality uses discrete ticks, never continuous waveform',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.chapdcha.real_page_flip/haptics'),
        (call) async {
          calls.add(call);
          if (call.method == 'getHapticCapabilities') {
            return {
              'hasVibrator': true,
              'hasAmplitudeControl': true,
              'hasAdvancedHaptics': false,
            };
          }
          return null;
        },
      );
      final handler = DefaultPageFlipEffectHandler(
        hapticQuality: HapticQuality.standard,
      );
      await Future<void>.delayed(Duration.zero);
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 0,
        intensity: 84,
        texture: 1,
        resistance: 1,
      );
      // Second grain after throttle window.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await handler.onHandleEffect(
        PageFlipEvent.texturedHaptic,
        pageIndex: 0,
        intensity: 84,
        texture: 0.8,
        resistance: 0.7,
      );

      final methods = calls
          .where((call) => call.method != 'getHapticCapabilities')
          .map((call) => call.method)
          .toList();
      expect(methods, isNot(contains('playContinuousWaveform')));
      expect(methods, contains('playTransient'));
      handler.dispose();
    });

    test('premium quality may emit continuous waveform on drag texture',
        () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.chapdcha.real_page_flip/haptics'),
        (call) async {
          calls.add(call);
          if (call.method == 'getHapticCapabilities') {
            return {
              'hasVibrator': true,
              'hasAmplitudeControl': true,
              'hasAdvancedHaptics': true,
            };
          }
          return null;
        },
      );
      final handler = DefaultPageFlipEffectHandler(
        hapticQuality: HapticQuality.premium,
      );
      await Future<void>.delayed(Duration.zero);
      // Feed enough frames to cross ContinuousHapticBuffer flush gap.
      for (var i = 0; i < 8; i++) {
        await handler.onHandleEffect(
          PageFlipEvent.texturedHaptic,
          pageIndex: 0,
          intensity: 84,
          texture: 0.5,
          resistance: 0.8,
        );
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }

      expect(
        calls.map((call) => call.method),
        contains('playContinuousWaveform'),
      );
      handler.dispose();
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

      test('detentHaptic sends a low-intensity, short, crisp playTransient',
          () async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.chapdcha.real_page_flip/haptics'),
          (methodCall) async {
            calls.add(methodCall);
            if (methodCall.method == 'getHapticCapabilities') {
              return {
                'hasVibrator': true,
                'hasAmplitudeControl': true,
                'hasAdvancedHaptics': true,
              };
            }
            return null;
          },
        );

        final handler = DefaultPageFlipEffectHandler();
        await Future<void>.delayed(Duration.zero);
        await handler.onHandleEffect(PageFlipEvent.detentHaptic);

        final hapticCalls = calls
            .where((call) => call.method != 'getHapticCapabilities')
            .toList();
        expect(hapticCalls, hasLength(1));
        expect(hapticCalls.single.method, 'playTransient');
        final args = hapticCalls.single.arguments as Map;
        // Deliberately subtle: well below the settle-thud intensity range, a
        // short duration so it reads as a tick layered on top of the ongoing
        // friction texture rather than a competing event.
        expect(args['intensity'], closeTo(0.28, 1e-6));
        expect(args['sharpness'], closeTo(0.68, 1e-6));
        expect(args['durationMs'], 12);
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

      test('texturedHaptic with texture above threshold does not throw',
          () async {
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

      test('texturedHaptic with texture below threshold does not throw',
          () async {
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
            volume: 1,
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
        final handler = DefaultPageFlipEffectHandler();
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
      for (var i = 0; i < 5; i++) {
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
      for (var i = 0; i < 3; i++) {
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
