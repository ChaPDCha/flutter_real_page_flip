import 'dart:async';

import 'package:flutter/services.dart';
import 'package:real_page_flip/src/models/haptic_quality.dart';

class AdvancedHapticEngine {
  AdvancedHapticEngine._();

  static const MethodChannel _channel =
      MethodChannel('com.chapdcha.real_page_flip/haptics');

  /// Reads hardware capability instead of inferring quality from device model.
  static Future<HapticCapabilities> getCapabilities() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getHapticCapabilities',
      );
      if (raw == null) return const HapticCapabilities.basic();
      return HapticCapabilities(
        hasVibrator: raw['hasVibrator'] == true,
        hasAmplitudeControl: raw['hasAmplitudeControl'] == true,
        hasAdvancedHaptics: raw['hasAdvancedHaptics'] == true,
      );
    } on MissingPluginException {
      return const HapticCapabilities.basic();
    } on PlatformException {
      return const HapticCapabilities.basic();
    }
  }

  /// 매우 짧고 날카로운 단일 이벤트 (드래그 시 텍스처 표현용)
  /// [intensity]: 0.0 ~ 1.0
  /// [sharpness]: 0.0 ~ 1.0
  static Future<void> playTransient({
    required double intensity,
    required double sharpness,
    required int durationMs,
  }) async {
    try {
      await _channel.invokeMethod('playTransient', {
        'intensity': intensity.clamp(0.0, 1.0),
        'sharpness': sharpness.clamp(0.0, 1.0),
        'durationMs': durationMs.clamp(1, 500).toInt(),
      });
    } on MissingPluginException {
      _fallbackTransient(intensity);
    } on PlatformException {
      _fallbackTransient(intensity);
    }
  }

  static void _fallbackTransient(double intensity) {
    if (intensity > 0.6) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// 묵직하고 끊어지는 느낌의 이벤트 (Release, Snap 표현용)
  /// [intensity]: 0.0 ~ 1.0
  static Future<void> playThud({required double intensity}) async {
    try {
      await _channel.invokeMethod('playThud', {
        'intensity': intensity.clamp(0.0, 1.0),
      });
    } on MissingPluginException {
      unawaited(HapticFeedback.heavyImpact());
    } on PlatformException {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  /// 스틱슬립(Friction slip) 해제 시 빠른 다중 transient 진동
  static Future<void> playSlipBurst({required double intensity}) async {
    try {
      await _channel.invokeMethod('playSlipBurst', {
        'intensity': intensity.clamp(0.0, 1.0),
      });
    } on MissingPluginException {
      unawaited(HapticFeedback.mediumImpact());
    } on PlatformException {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  /// 페이지가 착지할 때 묵직하고 만족스러운 안착 진동
  static Future<void> playSettleThud({required double intensity}) async {
    try {
      await _channel.invokeMethod('playSettleThud', {
        'intensity': intensity.clamp(0.0, 1.0),
      });
    } on MissingPluginException {
      unawaited(HapticFeedback.heavyImpact());
    } on PlatformException {
      unawaited(HapticFeedback.heavyImpact());
    }
  }

  /// 시작/경미한 이벤트 처리 (표준 시스템 햅틱 활용)
  static Future<void> playSystemMedium() async {
    try {
      await _channel.invokeMethod('playSystemMedium');
    } on MissingPluginException {
      unawaited(HapticFeedback.mediumImpact());
    } on PlatformException {
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  static Future<void> playSystemLight() async {
    try {
      await _channel.invokeMethod('playSystemLight');
    } on MissingPluginException {
      unawaited(HapticFeedback.lightImpact());
    } on PlatformException {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// Sends a continuous waveform segment to the native platform.
  ///
  /// [intensities] is a list of amplitude values (0.0-1.0) sampled at
  /// ~200 Hz (5 ms per sample). On iOS the values become a `CHHapticPattern`
  /// parameter curve on a persistent advanced player with real-time dynamic
  /// parameters. On Android they become a `VibrationEffect.createWaveform`
  /// amplitude array.
  ///
  /// Callers should flush at most every ~40 ms and keep each batch to
  /// ~8–10 samples so the MethodChannel payload stays small.
  static Future<void> playContinuousWaveform({
    required List<double> intensities,
    required double totalDurationMs,
    double sharpness = 0.45,
  }) async {
    if (intensities.isEmpty) return;
    try {
      await _channel.invokeMethod('playContinuousWaveform', {
        'intensities': intensities,
        'totalDurationMs': totalDurationMs,
        // iOS streams this into the persistent player's sharpness control so
        // fast flicks feel crisp and slow drags feel soft. Android has no
        // sharpness axis and ignores it.
        'sharpness': sharpness.clamp(0.0, 1.0),
      });
    } on MissingPluginException {
      _fallbackContinuous(intensities);
    } on PlatformException {
      _fallbackContinuous(intensities);
    }
  }

  /// Fallback when the native plugin does not support continuous waveforms.
  static void _fallbackContinuous(List<double> intensities) {
    // Pick the median intensity as a representative single transient.
    final sorted = List<double>.from(intensities)..sort();
    final median = sorted[sorted.length >> 1];
    if (median > 0.6) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// Stops any in-flight continuous waveform so the drag-end does not leave
  /// a springy tail or a stuck vibration.
  static Future<void> stopContinuous() async {
    try {
      await _channel.invokeMethod('stopContinuous');
    } on MissingPluginException {
      // No-op on platforms without the custom channel.
    } on PlatformException {
      // Ignore cancel failures.
    }
  }

  /// Stops any in-flight composition so drag-end does not leave a springy tail.
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod('cancel');
    } on MissingPluginException {
      // No-op on platforms without the custom channel.
    } on PlatformException {
      // Ignore cancel failures.
    }
  }
}
