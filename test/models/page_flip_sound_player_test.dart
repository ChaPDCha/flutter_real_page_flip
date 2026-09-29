import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import 'package:real_page_flip/src/widgets/default_page_flip_sound.dart';

import '../utils/test_helpers.dart';

class _RecordingSound implements PageFlipSoundPlayer {
  final List<double> played = <double>[];
  int warmUps = 0;
  int disposes = 0;

  @override
  FutureOr<void> warmUp() {
    warmUps++;
  }

  @override
  FutureOr<void> play({required double volume}) {
    played.add(volume);
  }

  @override
  void dispose() {
    disposes++;
  }
}

class _RecordingHandler implements PageFlipEffectHandler {
  final List<PageFlipEvent> events = <PageFlipEvent>[];

  @override
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {
    events.add(event);
  }

  @override
  set viewportWidth(double width) {}

  @override
  void dispose() {}
}

class _ThrowingSound implements PageFlipSoundPlayer {
  @override
  FutureOr<void> warmUp() {}

  @override
  FutureOr<void> play({required double volume}) =>
      Future<void>.error(StateError('no audio device'));

  @override
  void dispose() {}
}

void main() {
  setUpAll(() {
    setupAudioMocks();
    setupHapticMock();
  });
  tearDownAll(clearAllChannelMocks);

  Widget buildFlip({
    required PageFlipController controller,
    PageFlipSoundPlayer? soundPlayer,
    PageFlipEffectHandler? effectHandler,
    bool enableSound = true,
    void Function(PageFlipEvent, Object, StackTrace)? onEffectError,
  }) =>
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: PageFlipWidget(
            controller: controller,
            itemCount: 5,
            onEffectError: onEffectError,
            config: PageFlipConfig(
              duration: const Duration(milliseconds: 120),
              skipTapAnimation: false,
              enableSound: enableSound,
              soundPlayer: soundPlayer,
              effectHandler: effectHandler,
            ),
            itemBuilder: (context, index) => Text('page $index'),
          ),
        ),
      );

  testWidgets('host soundPlayer gets the sound; haptics stay on the handler',
      (tester) async {
    final controller = PageFlipController();
    final sound = _RecordingSound();
    final handler = _RecordingHandler();

    await tester.pumpWidget(
      buildFlip(
        controller: controller,
        soundPlayer: sound,
        effectHandler: handler,
      ),
    );
    await tester.pumpAndSettle();
    expect(sound.warmUps, 1, reason: 'Warmed once after the first frame');

    controller.nextPage();
    await tester.pumpAndSettle();

    expect(sound.played, hasLength(1));
    expect(sound.played.single, inInclusiveRange(0.0, 1.0));
    expect(handler.events, isNot(contains(PageFlipEvent.sound)));
    expect(handler.events, contains(PageFlipEvent.impulseHaptic));
  });

  testWidgets('enableSound: false neither warms nor plays the host player',
      (tester) async {
    final controller = PageFlipController();
    final sound = _RecordingSound();

    await tester.pumpWidget(
      buildFlip(
        controller: controller,
        soundPlayer: sound,
        effectHandler: _RecordingHandler(),
        enableSound: false,
      ),
    );
    await tester.pumpAndSettle();
    controller.nextPage();
    await tester.pumpAndSettle();

    expect(sound.warmUps, 0);
    expect(sound.played, isEmpty);
  });

  testWidgets('the engine never disposes a host-owned player', (tester) async {
    final sound = _RecordingSound();
    await tester.pumpWidget(
      buildFlip(
        controller: PageFlipController(),
        soundPlayer: sound,
        effectHandler: _RecordingHandler(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    expect(sound.disposes, 0);
  });

  testWidgets('a failing host player is reported, navigation continues',
      (tester) async {
    final controller = PageFlipController();
    final errors = <Object>[];
    await tester.pumpWidget(
      buildFlip(
        controller: controller,
        soundPlayer: _ThrowingSound(),
        effectHandler: _RecordingHandler(),
        onEffectError: (_, error, __) => errors.add(error),
      ),
    );
    await tester.pumpAndSettle();

    controller.nextPage();
    await tester.pumpAndSettle();

    expect(controller.isAttached, isTrue);
    expect(errors.whereType<StateError>(), hasLength(1));
  });

  group('DefaultPageFlipSound', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late bool Function(String asset) canLoad;

    setUp(() {
      calls = <MethodCall>[];
      canLoad = (_) => true;
      messenger.setMockMethodCallHandler(pageFlipSoundChannel, (call) async {
        calls.add(call);
        if (call.method == 'load') {
          final args = call.arguments as Map<Object?, Object?>;
          return canLoad(args['asset']! as String);
        }
        if (call.method == 'play') return true;
        return null;
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(pageFlipSoundChannel, null);
    });

    test('touches no channel until first use', () {
      final sound = DefaultPageFlipSound();
      expect(sound.debugLoadStarted, isFalse);
      expect(calls, isEmpty);
      sound.dispose();
      expect(calls, isEmpty, reason: 'Nothing to unload when never loaded');
    });

    test('play before loading is skipped and starts the load', () async {
      final sound = DefaultPageFlipSound()..play(volume: 0.5);
      expect(sound.debugLoadStarted, isTrue);
      await sound.warmUp();
      expect(calls.map((c) => c.method), <String>['load']);
      expect(sound.debugIsReady, isTrue);

      sound.play(volume: 0.5);
      await Future<void>.delayed(Duration.zero);
      final play = calls.last;
      expect(play.method, 'play');
      expect(
        (play.arguments as Map<Object?, Object?>)['volume'],
        cappedFlipSoundVolume(0.5),
      );
      sound.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(calls.last.method, 'unload');
    });

    test('bundled sound tries mp3 first, then opus', () async {
      canLoad = (asset) => asset.endsWith('.opus');
      final sound = DefaultPageFlipSound();
      await sound.warmUp();
      final assets = calls
          .where((c) => c.method == 'load')
          .map((c) => (c.arguments as Map<Object?, Object?>)['asset'])
          .toList();
      expect(assets, <String>[
        'packages/real_page_flip/assets/sounds/page_flip.mp3',
        'packages/real_page_flip/assets/sounds/page_flip.opus',
      ]);
      expect(sound.debugIsReady, isTrue);
      sound.dispose();
    });

    test('custom asset key is loaded instead of the bundled sound', () async {
      final sound = DefaultPageFlipSound(asset: 'assets/sounds/custom.mp3');
      await sound.warmUp();
      expect(
        (calls.single.arguments as Map<Object?, Object?>)['asset'],
        'assets/sounds/custom.mp3',
      );
      sound.dispose();
    });

    test('unsupported platform (desktop) is a silent no-op', () async {
      final sound = DefaultPageFlipSound(isSupported: false);
      await sound.warmUp();
      sound.play(volume: 0.5);
      sound.dispose();
      expect(calls, isEmpty);
    });

    test('platform support matrix: mobile and web only', () {
      for (final platform in TargetPlatform.values) {
        expect(
          platformHasDefaultSound(platform: platform, isWeb: false),
          platform == TargetPlatform.android || platform == TargetPlatform.iOS,
          reason: '$platform',
        );
        expect(platformHasDefaultSound(platform: platform, isWeb: true), true);
      }
    });

    test('a missing plugin never throws', () async {
      messenger.setMockMethodCallHandler(pageFlipSoundChannel, null);
      final sound = DefaultPageFlipSound();
      await sound.warmUp();
      expect(sound.debugIsReady, isFalse);
      expect(() => sound.play(volume: 0.5), returnsNormally);
      sound.dispose();
    });

    test('default handler with a host player does not dispose it', () {
      final sound = _RecordingSound();
      DefaultPageFlipEffectHandler(soundPlayer: sound).dispose();
      expect(sound.disposes, 0);
    });
  });

  test('copyWith / equality carry soundPlayer', () {
    final sound = _RecordingSound();
    final config = const PageFlipConfig().copyWith(soundPlayer: sound);
    expect(config.soundPlayer, same(sound));
    expect(config.normalized.soundPlayer, same(sound));
    expect(config == const PageFlipConfig(), isFalse);
    expect(config.copyWith(clearSoundPlayer: true).soundPlayer, isNull);
  });
}
