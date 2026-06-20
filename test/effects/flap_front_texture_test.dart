import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('flapFrontSourceRect', () {
    const imageSize = Size(800, 600);

    test('double spread forward flip uses right half of current spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(400));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('single page forward flip uses full snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: false,
        isForward: true,
      );

      expect(rect, equals(const Rect.fromLTWH(0, 0, 800, 600)));
    });

    test('double spread backward flip uses left half of current spread snapshot', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(0));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('single page backward flip returns full page rect (content on flap)', () {
      final rect = flapFrontSourceRect(
        imageSize: imageSize,
        isDoubleSpread: false,
        isForward: false,
      );
      expect(rect, isNotNull);
      expect(rect, equals(const Rect.fromLTWH(0, 0, 800, 600)));
    });
  });

  group('flapBackSourceRect', () {
    const imageSize = Size(800, 600);

    test('double spread forward uses left half (verso of right page)', () {
      final rect = flapBackSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(0));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('double spread backward uses right half (verso of left page)', () {
      final rect = flapBackSourceRect(
        imageSize: imageSize,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, isNotNull);
      expect(rect!.left, equals(400));
      expect(rect.top, equals(0));
      expect(rect.width, equals(400));
      expect(rect.height, equals(600));
    });

    test('single page forward returns null (no back content)', () {
      expect(
        flapBackSourceRect(
          imageSize: imageSize,
          isDoubleSpread: false,
          isForward: true,
        ),
        isNull,
      );
    });

    test('single page backward returns null (no back content)', () {
      expect(
        flapBackSourceRect(
          imageSize: imageSize,
          isDoubleSpread: false,
          isForward: false,
        ),
        isNull,
      );
    });
  });

  group('flapFrontDestRect', () {
    const size = Size(800, 600);

    test('double spread forward maps to right half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: true,
      );

      expect(rect, equals(const Rect.fromLTWH(400, 0, 400, 600)));
    });

    test('double spread backward maps to left half', () {
      final rect = flapFrontDestRect(
        size: size,
        isDoubleSpread: true,
        isForward: false,
      );

      expect(rect, equals(const Rect.fromLTWH(0, 0, 400, 600)));
    });

    test('single page uses full canvas', () {
      expect(
        flapFrontDestRect(
          size: size,
          isDoubleSpread: false,
          isForward: true,
        ),
        equals(const Rect.fromLTWH(0, 0, 800, 600)),
      );
      expect(
        flapFrontDestRect(
          size: size,
          isDoubleSpread: false,
          isForward: false,
        ),
        equals(const Rect.fromLTWH(0, 0, 800, 600)),
      );
    });
  });

  group('flapFrontContentRevealOpacity', () {
    test('starts visible and fades out quickly during early drag', () {
      expect(flapFrontContentRevealOpacity(0.0), equals(1.0));
      expect(
        flapFrontContentRevealOpacity(0.10, fadeOutEnd: 0.20),
        closeTo(0.5, 0.01),
      );
      expect(
        flapFrontContentRevealOpacity(0.20, fadeOutEnd: 0.20),
        equals(0.0),
      );
    });

    test('is zero during mid fold between fade-out and late reveal', () {
      expect(flapFrontContentRevealOpacity(0.25), equals(0.0));
      expect(flapFrontContentRevealOpacity(0.50), equals(0.0));
      expect(
        flapFrontContentRevealOpacity(0.84, revealStart: 0.85),
        equals(0.0),
      );
    });

    test('ramps smoothly during late settle reveal', () {
      expect(
        flapFrontContentRevealOpacity(
          0.90,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        closeTo(0.5, 0.01),
      );
    });

    test('is fully opaque at or after reveal end', () {
      expect(
        flapFrontContentRevealOpacity(
          0.95,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        equals(1.0),
      );
      expect(
        flapFrontContentRevealOpacity(
          1.0,
          revealStart: 0.85,
          revealEnd: 0.95,
        ),
        equals(1.0),
      );
    });
  });

  group('flapOpacityModulator', () {
    // ── Basics ──────────────────────────────────────────────

    test('start and end return 1.0 regardless of direction', () {
      expect(flapOpacityModulator(0.0), equals(1.0));
      expect(flapOpacityModulator(1.0), equals(1.0));
      expect(flapOpacityModulator(0.0, isForward: false), equals(1.0));
      expect(flapOpacityModulator(1.0, isForward: false), equals(1.0));
    });

    test('both strengths at zero return 1.0 throughout', () {
      for (final p in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        expect(
          flapOpacityModulator(p, thinPaperStrength: 0, endRevealStrength: 0),
          equals(1.0),
        );
      }
    });

    test('early exit avoids computation at extremes', () {
      expect(flapOpacityModulator(0.0, thinPaperStrength: 5.0), equals(1.0));
      expect(flapOpacityModulator(1.0, thinPaperStrength: 5.0), equals(1.0));
    });

    // ── Thin paper symmetry ─────────────────────────────────

    test('thin paper peaks at p = 0.5 for forward', () {
      const s = 0.2;
      final atMid = flapOpacityModulator(0.5, thinPaperStrength: s);
      final atNear = flapOpacityModulator(0.4, thinPaperStrength: s);
      expect(atMid, lessThan(1.0));
      expect(atMid, lessThan(atNear)); // 0.5 is minimum (most transparent)
    });

    test('thin paper symmetric for backward at same normalized position', () {
      const s = 0.2;
      // Forward at progress=0.3  → p=0.3
      // Backward at progress=0.7 → p=1-0.7=0.3
      final fwd = flapOpacityModulator(0.3, thinPaperStrength: s, isForward: true);
      final bwd = flapOpacityModulator(0.7, thinPaperStrength: s, isForward: false);
      expect(fwd, closeTo(bwd, 1e-15));
    });

    test('sin curve creates single trough at mid-flip', () {
      const s = 0.3;
      // Monotonic decrease 0→0.5
      double prev = 1.0;
      for (int i = 1; i <= 5; i++) {
        final p = i / 10.0;
        final v = flapOpacityModulator(p, thinPaperStrength: s, endRevealStrength: 0);
        expect(v, lessThan(prev));
        prev = v;
      }
      // Monotonic increase 0.5→1.0
      prev = flapOpacityModulator(0.5, thinPaperStrength: s, endRevealStrength: 0);
      for (int i = 6; i < 10; i++) {
        final p = i / 10.0;
        final v = flapOpacityModulator(p, thinPaperStrength: s, endRevealStrength: 0);
        expect(v, greaterThan(prev));
        prev = v;
      }
    });

    // ── End-reveal timing (CRITICAL: backward must match forward) ──

    test('end reveal activates from same normalized p regardless of direction', () {
      const s = 0.4;
      // Forward: progress=0.92  → p=0.92, end-reveal active
      // Backward: progress=0.08 → p=1-0.08=0.92, end-reveal active (SAME)
      final fwd = flapOpacityModulator(
        0.92, thinPaperStrength: 0, endRevealStrength: s, isForward: true);
      final bwd = flapOpacityModulator(
        0.08, thinPaperStrength: 0, endRevealStrength: s, isForward: false);
      expect(fwd, closeTo(bwd, 1e-15));
    });

    test('backward end-reveal does NOT activate near drag start', () {
      // Backward: start of drag = floatProgress=1.0 → p=0
      // Just after: floatProgress=0.95 → p=0.05 ≪ endRevealStart=0.85
      final atStart = flapOpacityModulator(
        0.95, thinPaperStrength: 0, endRevealStrength: 0.4, isForward: false);
      expect(atStart, equals(1.0),
          reason: 'Backward end-reveal must NOT trigger at drag start');

      // Mid-backward: floatProgress=0.5 → p=0.5
      final mid = flapOpacityModulator(
        0.5, thinPaperStrength: 0, endRevealStrength: 0.4, isForward: false);
      expect(mid, equals(1.0),
          reason: 'Backward end-reveal must NOT trigger mid-drag');
    });

    test('backward end-reveal activates near end of drag', () {
      // Backward: end of drag = floatProgress=0.0 → p=1.0
      // Near end: floatProgress=0.1 → p=0.9 > endRevealStart=0.85
      final nearEnd = flapOpacityModulator(
        0.1, thinPaperStrength: 0, endRevealStrength: 0.4, isForward: false);
      expect(nearEnd, lessThan(1.0),
          reason: 'Backward end-reveal MUST activate near drag end');
    });

    // ── Smoothstep mathematical properties ──────────────────

    test('end reveal uses C1-smooth smoothstep (zero slope at boundaries)', () {
      const s = 0.5;
      final atStart = flapOpacityModulator(
        0.85, thinPaperStrength: 0, endRevealStrength: s, endRevealStart: 0.85);
      final justAfter = flapOpacityModulator(
        0.8501, thinPaperStrength: 0, endRevealStrength: s, endRevealStart: 0.85);
      expect((atStart - justAfter).abs(), lessThan(0.001),
          reason: 'Smoothstep derivative should be ~0 at boundary');
    });

    // ── Exact mathematical values ───────────────────────────

    test('exact values for default parameters at mid-flip', () {
      // p=0.5: thinFactor = sin(0.5π) * 0.15 = 0.15
      // endFactor = 0 (p < 0.85)
      // result = 1.0 - 0.15 = 0.85
      expect(flapOpacityModulator(0.5), closeTo(0.85, 0.001));
    });

    test('exact smoothstep value at t = 0.5', () {
      // p=0.9, endRevealStart=0.8 → revealT = (0.9-0.8)/(1.0-0.8) = 0.5
      // smoothstep(0.5) = 0.5² * (3 - 2*0.5) = 0.25 * 2 = 0.5
      // endFactor = 0.5 * 0.5 = 0.25
      // result = 1.0 - 0.25 = 0.75
      final v = flapOpacityModulator(0.9,
          thinPaperStrength: 0,
          endRevealStrength: 0.5,
          endRevealStart: 0.8);
      expect(v, closeTo(0.75, 0.001),
          reason: 'smoothstep at t=0.5 halve endRevealStrength');
    });

    // ── Clamping ────────────────────────────────────────────

    test('clamped to minimum 0.2 even with extreme strength', () {
      expect(
        flapOpacityModulator(0.5, thinPaperStrength: 10.0),
        closeTo(0.2, 0.001),
      );
    });

    // ── Combined effect ────────────────────────────────────

    test('combined thin + end reveal compounds correctly', () {
      const s = 0.2;
      const es = 0.3;
      const rs = 0.85;
      final thin = flapOpacityModulator(0.92, thinPaperStrength: s, endRevealStrength: 0);
      final endOnly = flapOpacityModulator(0.92,
          thinPaperStrength: 0, endRevealStrength: es, endRevealStart: rs);
      final both = flapOpacityModulator(0.92,
          thinPaperStrength: s, endRevealStrength: es, endRevealStart: rs);

      expect(both, lessThan(thin));
      expect(both, lessThan(endOnly));
      // Both effects subtract: both ≈ thin + endOnly - 1.0
      expect(both, closeTo(thin + endOnly - 1.0, 0.001));
    });

    // ── Full-direction symmetry sweep ───────────────────────

    test('forward and backward produce identical outputs at equivalent positions', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final fwd = flapOpacityModulator(p,
            thinPaperStrength: 0.15, endRevealStrength: 0.35);
        final bwd = flapOpacityModulator(1.0 - p,
            thinPaperStrength: 0.15, endRevealStrength: 0.35, isForward: false);
        expect(fwd, closeTo(bwd, 1e-15),
            reason: 'Symmetry mismatch at p=$p');
      }
    });
  });
}
