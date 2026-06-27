import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Creates a solid-color [ui.Image] for testing snapshot-dependent layers.
Future<ui.Image> createTestImage(Size size, Color color) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = color,
  );
  return recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
}

/// Creates a half-and-half spread image for double-spread mode.
Future<ui.Image> createSpreadImage(Size size, Color left, Color right) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final half = size.width / 2;
  canvas.drawRect(
    Rect.fromLTWH(0, 0, half, size.height),
    Paint()..color = left,
  );
  canvas.drawRect(
    Rect.fromLTWH(half, 0, half, size.height),
    Paint()..color = right,
  );
  return recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
}

/// No-op effect handler that avoids platform channel / audio dependencies.
class NoOpEffectHandler implements PageFlipEffectHandler {
  const NoOpEffectHandler();

  @override
  FutureOr<void> onHandleEffect(
    PageFlipEvent event, {
    int? intensity,
    int? pageIndex,
    double? volume,
    double? texture,
    double? resistance,
  }) {}

  @override
  set viewportWidth(double width) {}

  @override
  void dispose() {}
}

/// Sets up mock platform channels for audioplayers (3 channels).
void setupAudioMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers.global/events',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      (call) async => null,
    );
  }
}

/// Sets up mock platform channel for haptics.
void setupHapticMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.chapdcha.real_page_flip/haptics'),
    (call) async => null,
  );
}

/// Clears all platform channel mocks (call in tearDownAll).
void clearAllChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final channel in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers.global/events',
    'com.chapdcha.real_page_flip/haptics',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(channel),
      null,
    );
  }
}
