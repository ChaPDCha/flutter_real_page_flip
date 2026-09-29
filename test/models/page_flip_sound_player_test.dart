import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

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
    test('allocates no audio player until first use', () {
      final sound = DefaultPageFlipSound();
      expect(sound.debugAllocatedPlayerCount, 0);
      expect(sound.debugIsReady, isFalse);
      sound.dispose();
    });

    test('play before loading is skipped and starts the load', () {
      final sound = DefaultPageFlipSound()..play(volume: 0.5);
      // The skipped play kicked off loading.
      expect(sound.debugAllocatedPlayerCount, greaterThan(0));
      // Do not await the load: audioplayers waits for a native "prepared"
      // event that the channel mocks never send.
      sound.dispose();
      expect(sound.debugAllocatedPlayerCount, 0);
    });

    test('custom asset key is accepted', () {
      final sound = DefaultPageFlipSound(asset: 'assets/sounds/custom.mp3');
      expect(sound.asset, 'assets/sounds/custom.mp3');
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
