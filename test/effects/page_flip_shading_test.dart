import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_shading.dart';
import 'package:real_page_flip/src/models/page_flip_config.dart';

void main() {
  // ─── edgeMaskPeakOpacity ───
  group('edgeMaskPeakOpacity', () {
    test('dark paper returns 0.7 (partial mask, avoids hard band)', () {
      expect(edgeMaskPeakOpacity(isPaperDark: true), 0.7);
    });
    test('light paper returns 1.0 (full mask, invisible on matching paper)', () {
      expect(edgeMaskPeakOpacity(isPaperDark: false), 1.0);
    });
  });

  // ─── edgeMaskWidth ───
  group('edgeMaskWidth', () {
    test('light paper returns 8 px at 1x DPR', () {
      expect(edgeMaskWidth(isPaperDark: false), 8.0);
    });
    test('dark paper returns 5 px at 1x DPR', () {
      expect(edgeMaskWidth(isPaperDark: true), 5.0);
    });
    test('light paper returns 10 px at 2x DPR (1.25x scale)', () {
      expect(edgeMaskWidth(isPaperDark: false, devicePixelRatio: 2), 10.0);
    });
    test('dark paper returns 6.25 px at 2x DPR (1.25x scale)', () {
      expect(edgeMaskWidth(isPaperDark: true, devicePixelRatio: 2), 6.25);
    });
    test('DPR below 2.0 uses no scale multiplier', () {
      expect(edgeMaskWidth(isPaperDark: false, devicePixelRatio: 1.99), 8.0);
      expect(edgeMaskWidth(isPaperDark: true, devicePixelRatio: 1.99), 5.0);
    });
    test('default devicePixelRatio is 1.0', () {
      expect(edgeMaskWidth(isPaperDark: false), 8.0);
      expect(edgeMaskWidth(isPaperDark: true), 5.0);
    });
  });

  // ─── foldMaskWidth ───
  group('foldMaskWidth', () {
    test('light paper returns 6 px at 1x DPR', () {
      expect(foldMaskWidth(isPaperDark: false), 6.0);
    });
    test('dark paper returns 4 px at 1x DPR', () {
      expect(foldMaskWidth(isPaperDark: true), 4.0);
    });
    test('light paper returns 7.5 px at 2x DPR (1.25x scale)', () {
      expect(foldMaskWidth(isPaperDark: false, devicePixelRatio: 2), 7.5);
    });
    test('dark paper returns 5 px at 2x DPR (1.25x scale)', () {
      expect(foldMaskWidth(isPaperDark: true, devicePixelRatio: 2), 5.0);
    });
    test('fold masks are narrower than edge masks (creases are subtler)', () {
      // At every combination foldWidth < edgeWidth.
      expect(
        foldMaskWidth(isPaperDark: false),
        lessThan(edgeMaskWidth(isPaperDark: false)),
      );
      expect(
        foldMaskWidth(isPaperDark: true),
        lessThan(edgeMaskWidth(isPaperDark: true)),
      );
    });
  });

  // ─── flapHighlightTone ───
  group('flapHighlightTone', () {
    test('dark paper returns cool off-white tint', () {
      final tone = flapHighlightTone(isPaperDark: true);
      expect(tone, const Color(0xFFE8E8F0));
    });
    test('light paper returns warm paper-white tint', () {
      final tone = flapHighlightTone(isPaperDark: false);
      expect(tone, const Color(0xFFFFF4E0));
    });
    test('dark and light tones are distinct', () {
      expect(
        flapHighlightTone(isPaperDark: true),
        isNot(flapHighlightTone(isPaperDark: false)),
      );
    });
    test('both tones are opaque (no alpha)', () {
      expect(flapHighlightTone(isPaperDark: true).alpha, 255);
      expect(flapHighlightTone(isPaperDark: false).alpha, 255);
    });
  });

  // ─── flapHighlightPeakBase ───
  group('flapHighlightPeakBase', () {
    test('dark paper returns 0.07 (dimmer for near-black stock)', () {
      expect(flapHighlightPeakBase(isPaperDark: true), 0.07);
    });
    test('light paper returns 0.10', () {
      expect(flapHighlightPeakBase(isPaperDark: false), 0.10);
    });
    test('dark is dimmer than light (matte paper avoids plastic sheen)', () {
      expect(
        flapHighlightPeakBase(isPaperDark: true),
        lessThan(flapHighlightPeakBase(isPaperDark: false)),
      );
    });
  });

  // ─── flapHighlightMidBase ───
  group('flapHighlightMidBase', () {
    test('dark paper returns 0.04', () {
      expect(flapHighlightMidBase(isPaperDark: true), 0.04);
    });
    test('light paper returns 0.06', () {
      expect(flapHighlightMidBase(isPaperDark: false), 0.06);
    });
    test('mid is lower than peak on both themes (smooth roll-off)', () {
      expect(
        flapHighlightMidBase(isPaperDark: true),
        lessThan(flapHighlightPeakBase(isPaperDark: true)),
      );
      expect(
        flapHighlightMidBase(isPaperDark: false),
        lessThan(flapHighlightPeakBase(isPaperDark: false)),
      );
    });
  });

  // ─── discreteShadowTone ───
  group('discreteShadowTone', () {
    test('dark paper returns moonlit off-white (same hue as highlight)', () {
      expect(discreteShadowTone(isPaperDark: true), const Color(0xFFE8E8F0));
    });
    test('light paper returns pure black', () {
      expect(discreteShadowTone(isPaperDark: false), Colors.black);
    });
    test('uses same cool tint as flapHighlightTone on dark paper', () {
      expect(
        discreteShadowTone(isPaperDark: true),
        flapHighlightTone(isPaperDark: true),
      );
    });
  });

  // ─── glowBandWidthScale ───
  group('glowBandWidthScale', () {
    test('dark paper returns 1.6 (wider, softer falloff)', () {
      expect(glowBandWidthScale(isPaperDark: true), 1.6);
    });
    test('light paper returns 1.0 (shadows already blend naturally)', () {
      expect(glowBandWidthScale(isPaperDark: false), 1.0);
    });
    test('scale > 1 only for dark paper', () {
      expect(glowBandWidthScale(isPaperDark: true), greaterThan(1.0));
      expect(glowBandWidthScale(isPaperDark: false), 1.0);
    });
  });

  // ─── freeEdgeContactLiftGain ───
  group('freeEdgeContactLiftGain', () {
    test('single-page returns 0 (tight grounding shadow, no lift)', () {
      expect(
        freeEdgeContactLiftGain(
          profile: DevicePerformanceProfile.high,
          isDoubleSpread: false,
        ),
        0,
      );
      expect(
        freeEdgeContactLiftGain(
          profile: DevicePerformanceProfile.medium,
          isDoubleSpread: false,
        ),
        0,
      );
    });
    test('double-spread HIGH returns 1.3 (full soft penumbra)', () {
      expect(
        freeEdgeContactLiftGain(
          profile: DevicePerformanceProfile.high,
          isDoubleSpread: true,
        ),
        1.3,
      );
    });
    test('double-spread MEDIUM returns 0.55 (modest lift)', () {
      expect(
        freeEdgeContactLiftGain(
          profile: DevicePerformanceProfile.medium,
          isDoubleSpread: true,
        ),
        0.55,
      );
    });
    test('double-spread LOW returns 0.55 (same as medium base)', () {
      expect(
        freeEdgeContactLiftGain(
          profile: DevicePerformanceProfile.low,
          isDoubleSpread: true,
        ),
        0.55,
      );
    });
    test('single-page return 0 regardless of profile', () {
      for (final profile in DevicePerformanceProfile.values) {
        expect(
          freeEdgeContactLiftGain(profile: profile, isDoubleSpread: false),
          0,
          reason: 'profile=$profile must not lift single-page shadow',
        );
      }
    });
  });

  // ─── flapFrontContentRevealOpacity ───
  group('flapFrontContentRevealOpacity', () {
    // ── Double-spread path ──
    test('double-spread always returns 1 (verso is physical)', () {
      // Phase 1 (early), 2 (mid), 3 (settle) — all should be 1.
      expect(
        flapFrontContentRevealOpacity(0, isDoubleSpread: true),
        1.0,
      );
      expect(
        flapFrontContentRevealOpacity(0.5, isDoubleSpread: true),
        1.0,
      );
      expect(
        flapFrontContentRevealOpacity(1, isDoubleSpread: true),
        1.0,
      );
      // Even backward flip.
      expect(
        flapFrontContentRevealOpacity(0.3,
            isDoubleSpread: true, isForward: false,),
        1.0,
      );
    });

    // ── Single-page keep-content-visible path ──
    test(
        'single-page keepSinglePageContentVisible=true returns 1 throughout', () {
      expect(
        flapFrontContentRevealOpacity(0,),
        1.0,
      );
      expect(
        flapFrontContentRevealOpacity(0.5,),
        1.0,
      );
      expect(
        flapFrontContentRevealOpacity(1,),
        1.0,
      );
    });

    // ── Disabled settle reveal ──
    test('single-page enableSinglePageSettleReveal=false returns 0', () {
      expect(
        flapFrontContentRevealOpacity(0.3,
            keepSinglePageContentVisible: false,
            enableSinglePageSettleReveal: false,),
        0,
      );
      expect(
        flapFrontContentRevealOpacity(0.9,
            keepSinglePageContentVisible: false,
            enableSinglePageSettleReveal: false,),
        0,
      );
    });

    // ── Three-phase curve (single-page, lightweight) ──
    group('single-page lightweight three-phase curve', () {
      // Shared params for the lightweight single-page path.
      double reveal(double progress, {bool isForward = true}) =>
          flapFrontContentRevealOpacity(
            progress,
            keepSinglePageContentVisible: false,
            isForward: isForward,
          );

      test('Phase 1: early drag fades from 1 toward 0', () {
        expect(reveal(0), closeTo(1.0, 0.001)); // very start
        expect(reveal(0.10), closeTo(0.5, 0.05)); // mid-fade (smoothstep)
        expect(reveal(0.20), closeTo(0.0, 0.001)); // end of fadeOutEnd
      });

      test('Phase 2: mid-fold stays at floor (0)', () {
        expect(reveal(0.3), 0.0);
        expect(reveal(0.5), 0.0);
        expect(reveal(0.8), 0.0);
        // Just before revealStart (default 0.85).
        expect(reveal(0.849), 0.0);
      });

      test('Phase 3: late settle reveals from 0 to 1', () {
        expect(reveal(0.85), closeTo(0.0, 0.001)); // reveal start
        expect(reveal(0.90), closeTo(0.5, 0.1)); // mid-reveal
        expect(reveal(0.95), closeTo(1.0, 0.001)); // reveal end
        expect(reveal(1), 1.0); // fully settled
      });

      test('backward flip normalizes progress correctly', () {
        // progress 1.0→0 (backward) maps to normalized 0→1.
        // At raw progress=0.8 backward: normalized = 0.2 → Phase 1.
        final at80 = reveal(0.8, isForward: false);
        final at20 = reveal(0.2);
        expect(at80, closeTo(at20, 0.001));
      });

      test('monotonically increasing in Phase 3', () {
        var prev = reveal(0.85);
        for (final p in [0.87, 0.89, 0.91, 0.93, 0.95]) {
          final curr = reveal(p);
          expect(curr, greaterThanOrEqualTo(prev - 0.001),
              reason: 'p=$p should be >= p=${p - 0.02}',);
          prev = curr;
        }
      });
    });

    // ── Edge cases ──
    test('fadeOutEnd=0: Phase 1 skipped, goes straight to bleed floor', () {
      final result = flapFrontContentRevealOpacity(
        0,
        fadeOutEnd: 0,
        keepSinglePageContentVisible: false,
      );
      expect(result, 0.0); // bleed floor
    });

    test('custom reveal window shifts Phase 3', () {
      final beforeWindow = flapFrontContentRevealOpacity(
        0.75,
        revealStart: 0.80,
        revealEnd: 0.90,
        keepSinglePageContentVisible: false,
      );
      expect(beforeWindow, 0.0); // still in Phase 2

      final midWindow = flapFrontContentRevealOpacity(
        0.85,
        revealStart: 0.80,
        revealEnd: 0.90,
        keepSinglePageContentVisible: false,
      );
      expect(midWindow, inInclusiveRange(0.01, 0.99)); // mid-reveal

      final afterWindow = flapFrontContentRevealOpacity(
        0.95,
        revealStart: 0.80,
        revealEnd: 0.90,
        keepSinglePageContentVisible: false,
      );
      expect(afterWindow, 1.0); // fully revealed
    });
  });

  // ─── middleLayerOpacity ───
  group('middleLayerOpacity', () {
    test('backward flip always returns 1 (blocks host background)', () {
      expect(middleLayerOpacity(0, isForward: false), 1.0);
      expect(middleLayerOpacity(0.5, isForward: false), 1.0);
      expect(middleLayerOpacity(0.9, isForward: false), 1.0);
      expect(middleLayerOpacity(1, isForward: false), 1.0);
    });

    test('forward flip: fully opaque before revealStart', () {
      expect(middleLayerOpacity(0, isForward: true), 1.0);
      expect(middleLayerOpacity(0.5, isForward: true), 1.0);
      expect(middleLayerOpacity(0.84, isForward: true), 1.0);
    });

    test('forward flip: fully transparent after revealEnd', () {
      expect(middleLayerOpacity(0.95, isForward: true), 0.0);
      expect(middleLayerOpacity(1, isForward: true), 0.0);
    });

    test('forward flip: smoothstep fade in settle window', () {
      final mid = middleLayerOpacity(0.90, isForward: true);
      expect(mid, inInclusiveRange(0.01, 0.99)); // not 0 or 1 at mid-window
    });

    test('forward flip: non-increasing across settle window', () {
      var prev = middleLayerOpacity(0.85, isForward: true);
      for (final p in [0.87, 0.89, 0.91, 0.93, 0.95]) {
        final curr = middleLayerOpacity(p, isForward: true);
        expect(curr, lessThanOrEqualTo(prev + 0.001),
            reason: 'p=$p should be <= p-0.02',);
        prev = curr;
      }
    });

    test('tiny reveal window clamps to 0 after revealStart', () {
      final result = middleLayerOpacity(
        0.85,
        isForward: true,
        revealEnd: 0.851,
      );
      // Near-immediate transition: at 0.855 it should be close to 0.
      final after = middleLayerOpacity(
        0.855,
        isForward: true,
        revealEnd: 0.851,
      );
      expect(after, closeTo(0.0, 0.001));
    });
  });

  // ─── singlePageBackDim ───
  group('singlePageBackDim', () {
    test('backOpacity >= 1.0 returns 1 (no dim)', () {
      expect(
        singlePageBackDim(0.5, backOpacity: 1),
        1.0,
      );
      expect(
        singlePageBackDim(0.5, backOpacity: 1.5),
        1.0,
      );
    });

    test('holds backOpacity through peel phase (before revealStart)', () {
      expect(
        singlePageBackDim(0, backOpacity: 0.35),
        0.35,
      );
      expect(
        singlePageBackDim(0.5, backOpacity: 0.35),
        0.35,
      );
      expect(
        singlePageBackDim(0.84, backOpacity: 0.35),
        0.35,
      );
    });

    test('returns 1.0 after revealEnd', () {
      expect(
        singlePageBackDim(0.95, backOpacity: 0.35),
        1.0,
      );
      expect(
        singlePageBackDim(1, backOpacity: 0.35),
        1.0,
      );
    });

    test('eases smoothly from backOpacity to 1.0 in settle window', () {
      final atStart =
          singlePageBackDim(0.85, backOpacity: 0.35);
      final atMid =
          singlePageBackDim(0.90, backOpacity: 0.35);
      final atEnd =
          singlePageBackDim(0.95, backOpacity: 0.35);

      expect(atStart, closeTo(0.35, 0.001));
      expect(atMid, inInclusiveRange(0.36, 0.99));
      expect(atEnd, 1.0);
    });

    test('monotonically increasing across settle window', () {
      var prev = singlePageBackDim(0.85, backOpacity: 0.35);
      for (final p in [0.87, 0.89, 0.91, 0.93, 0.95]) {
        final curr = singlePageBackDim(p, backOpacity: 0.35);
        expect(curr, greaterThanOrEqualTo(prev - 0.001),
            reason: 'p=$p should be >= previous',);
        prev = curr;
      }
    });

    test('tiny divisor (revealEnd ≈ revealStart) returns 1.0 after window', () {
      final result = singlePageBackDim(
        0.86,
        backOpacity: 0.35,
        revealEnd: 0.851,
      );
      expect(result, 1.0);
    });

    test('backOpacity=0 returns 0 in peel, eases to 1', () {
      expect(singlePageBackDim(0.5, backOpacity: 0), 0.0);
      expect(singlePageBackDim(0.95, backOpacity: 0), 1.0);
    });
  });

  // ─── flapOpacityModulator ───
  group('flapOpacityModulator', () {
    test('returns 1.0 at progress extremes', () {
      expect(flapOpacityModulator(0), 1.0);
      expect(flapOpacityModulator(1), 1.0);
    });

    test('returns 1.0 when both strengths are 0', () {
      expect(
        flapOpacityModulator(0.5,
            thinPaperStrength: 0,),
        1.0,
      );
    });

    test('thinPaper peaks at mid-flip (p=0.5)', () {
      final atMid = flapOpacityModulator(0.5, thinPaperStrength: 0.3);
      final atQuarter = flapOpacityModulator(0.25, thinPaperStrength: 0.3);
      expect(atMid, lessThan(atQuarter)); // more transparent at peak
    });

    test('thinPaper at peak: sin(π/2)=1, so opacity = 1 - strength', () {
      final result = flapOpacityModulator(0.5, thinPaperStrength: 0.2);
      expect(result, closeTo(0.8, 0.001)); // 1.0 - 0.2
    });

    test('endReveal fade near the finish', () {
      final at92 =
          flapOpacityModulator(0.92, endRevealStrength: 0.5);
      final at98 =
          flapOpacityModulator(0.98, endRevealStrength: 0.5);
      expect(at98, lessThan(at92)); // closer to end = more transparent
    });

    test('clamp floor at 0.05', () {
      // Make both effects strong enough to push below zero.
      final result = flapOpacityModulator(
        0.5,
        thinPaperStrength: 1,
        endRevealStrength: 1,
      );
      expect(result, 0.05); // floor
    });

    test('backward flip inverts progress', () {
      // p=0.1 forward (early) vs p=0.9 backward (also early after normalization).
      final fwd =
          flapOpacityModulator(0.1, thinPaperStrength: 0.3);
      final bwd =
          flapOpacityModulator(0.9, isForward: false, thinPaperStrength: 0.3);
      expect(fwd, closeTo(bwd, 0.001));
    });

    test('mid-flip backward: raw p=0.5, normalized p=0.5 (same as forward)', () {
      final fwd =
          flapOpacityModulator(0.5, thinPaperStrength: 0.3);
      final bwd =
          flapOpacityModulator(0.5, isForward: false, thinPaperStrength: 0.3);
      expect(fwd, closeTo(bwd, 0.001));
    });

    test('all results are within [0.05, 1.0]', () {
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 1.0]) {
        final result = flapOpacityModulator(
          p,
          thinPaperStrength: 0.3,
          endRevealStrength: 0.5,
        );
        expect(result, inInclusiveRange(0.05, 1.0),
            reason: 'p=$p returned $result',);
      }
      // Backward too.
      for (final p in [0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0]) {
        final result = flapOpacityModulator(
          p,
          thinPaperStrength: 0.3,
          endRevealStrength: 0.5,
          isForward: false,
        );
        expect(result, inInclusiveRange(0.05, 1.0),
            reason: 'backward p=$p returned $result',);
      }
    });
  });
}
