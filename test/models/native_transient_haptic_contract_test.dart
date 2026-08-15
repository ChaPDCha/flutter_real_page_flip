import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String androidSource;
  late String iosSource;

  setUpAll(() {
    androidSource = File(
      p.join(
        Directory.current.path,
        'android',
        'src',
        'main',
        'kotlin',
        'com',
        'chapdcha',
        'real_page_flip',
        'RealPageFlipPlugin.kt',
      ),
    ).readAsStringSync();
    iosSource = File(
      p.join(
        Directory.current.path,
        'ios',
        'real_page_flip',
        'Sources',
        'real_page_flip',
        'RealPageFlipPlugin.swift',
      ),
    ).readAsStringSync();
  });

  test('Android amplitude route preserves transient edge and weight', () {
    expect(androidSource, contains('buildTransientEnvelope'));
    expect(
      androidSource,
      contains('if (clampedDuration <= 16 &&'),
      reason: 'Weighted landings must not collapse into a fixed primitive tick',
    );
    expect(
      androidSource,
      contains(
        'createWaveform(envelope.timings, envelope.amplitudes, -1)',
      ),
      reason: 'A one-shot discards the authored sharpness cue',
    );
  });

  test('iOS weighted transient has a crisp edge and decaying paper tail', () {
    expect(iosSource, contains('let continuousTail'));
    expect(iosSource, contains('let transientEdge'));
    expect(iosSource, contains('clampedDurationMs <= 25'));
    expect(iosSource, contains('let decayCurve = CHHapticParameterCurve'));
    expect(iosSource, contains('parameterCurves: [decayCurve]'));
    expect(
      iosSource,
      contains('relativeTime: durationSeconds, value: 0.12'),
      reason: 'The weighted tail must decay instead of becoming a flat buzz',
    );
    expect(
      iosSource,
      contains('events: [continuousTail, transientEdge]'),
      reason: 'A plain continuous event feels like a buzz, not paper landing',
    );
  });
}
