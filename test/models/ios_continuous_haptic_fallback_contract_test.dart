import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Locks the iOS native continuous-waveform fallback contract.
///
/// Threat: paper-scrape intensities (typically ≤0.55) hit a median > 0.6 gate
/// and produce silence when CHHapticAdvancedPatternPlayer creation/scheduling
/// fails — unlike Android's always-on median one-shot fallback.
void main() {
  late String swiftSource;

  setUpAll(() {
    final pluginPath = p.join(
      Directory.current.path,
      'ios',
      'real_page_flip',
      'Sources',
      'real_page_flip',
      'RealPageFlipPlugin.swift',
    );
    swiftSource = File(pluginPath).readAsStringSync();
  });

  test('exposes playContinuousFallback for soft paper-scrape batches', () {
    expect(swiftSource, contains('playContinuousFallback'));
    expect(
      swiftSource,
      contains('max(min(median, 1.0), 0.22)'),
      reason: 'Fallback must floor soft scrape intensities above selection-only',
    );
  });

  test('continuous failure paths never gate on median > 0.6', () {
    expect(
      swiftSource.contains('if median > 0.6'),
      isFalse,
      reason: 'median > 0.6 left kraft/standard scrape silent on player failure',
    );
    expect(
      swiftSource.contains('intensities.contains(where: { \$0 > 0.6 })'),
      isFalse,
    );
  });

  test('continuous base intensity is 1.0 so control curves map 1:1', () {
    expect(
      swiftSource,
      contains('hapticIntensity, value: 1.0'),
      reason: 'Base 0.55 double-attenuated Dart amplitudes vs Android waveform',
    );
    expect(swiftSource, contains('hapticIntensityControl'));
    expect(
      swiftSource,
      contains('value: 0'),
      reason: 'Player must start silenced before the first intensity curve',
    );
  });

  test('schedule/send failure emits discrete fallback', () {
    final catchBlock = RegExp(
      r'catch \{\s*// Drop the player[\s\S]*?playContinuousFallback',
      multiLine: true,
    );
    expect(
      catchBlock.hasMatch(swiftSource),
      isTrue,
      reason: 'Parameter-curve failures must not drop the batch silently',
    );
  });
}
