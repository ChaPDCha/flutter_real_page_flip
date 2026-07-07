import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/controllers/page_flip_state_controller.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_effect_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.chapdcha.real_page_flip/haptics'),
      (methodCall) async => null,
    );
  });

  group('Haptic Preset Baseline Measurement', () {
    test('Measure all presets', () async {
      print(
        '\n================== HAPTIC PRESET BASELINE MEASUREMENT ==================',
      );
      const presets = PaperTexturePreset.values;

      // We will simulate a slow drag sequence for each preset.
      // Velocity intensity: 45 (slow drag), foldAngle/texture: 0.5, resistance: 0.5.
      for (final preset in presets) {
        print('\nPreset: $preset');
        final handler = DefaultPageFlipEffectHandler(
          hapticTexturePreset: preset,
        );
        await Future<void>.delayed(Duration.zero);

        // Let's send 5 consecutive ticks to see the throttling and calculations
        for (var i = 0; i < 5; i++) {
          await handler.onHandleEffect(
            PageFlipEvent.texturedHaptic,
            pageIndex: 0,
            intensity: 45, // Slow drag
            texture: 0.5, // Halfway folded
            resistance: 0.5,
          );
          // Wait 35ms between updates to trigger throttle checks
          await Future<void>.delayed(const Duration(milliseconds: 35));
        }
        handler.dispose();
      }
      print(
        '========================================================================\n',
      );
    });
  });
}
