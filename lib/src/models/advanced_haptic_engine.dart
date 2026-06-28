import 'dart:async';

import 'package:flutter/services.dart';

class AdvancedHapticEngine {
  AdvancedHapticEngine._();

  static const MethodChannel _channel =
      MethodChannel('com.chapdcha.real_page_flip/haptics');

  /// 매우 짧고 날카로운 단일 이벤트 (드래그 시 텍스처 표현용)
  /// [intensity]: 0.0 ~ 1.0
  /// [sharpness]: 0.0 ~ 1.0
  static Future<void> playTransient({
    required double intensity,
    required double sharpness,
  }) async {
    try {
      await _channel.invokeMethod('playTransient', {
        'intensity': intensity.clamp(0.0, 1.0),
        'sharpness': sharpness.clamp(0.0, 1.0),
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
}
