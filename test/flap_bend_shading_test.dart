import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_shading.dart';

/// The turning sheet in double-spread barely moves in geometry — its material
/// width grows and it takes a small `rotateZ`, and that is all. Everything a
/// reader perceives as "this page is bending" therefore comes from this
/// profile, which is why it is asserted as a shape rather than a constant.
void main() {
  group('flapBendShadowAlphaAt — the sheet reads as a curled cylinder', () {
    test('reaches the fold instead of fading out mid-flap', () {
      // The previous profile died at u ~= 0.62, leaving the third of the flap
      // nearest the binding unshaded — the flattest possible place to leave
      // flat, since that is where a real page bends hardest.
      expect(flapBendShadowAlphaAt(1), greaterThan(0.9));
      expect(flapBendShadowAlphaAt(0.8), greaterThan(0.6));
      expect(flapBendShadowAlphaAt(0.62), greaterThan(0.4));
    });

    test('darkens monotonically over the fold-side half', () {
      // Stepped over integers: accumulating 0.05 in a double overshoots 1.0
      // and lands outside the profile's domain, which returns 0.
      var previous = flapBendShadowAlphaAt(0.5);
      for (var i = 11; i <= 20; i++) {
        final u = i / 20;
        final current = flapBendShadowAlphaAt(u);
        expect(current, greaterThan(previous), reason: 'at u=$u');
        previous = current;
      }
    });

    test('keeps a distinct lobe at the lifted free edge', () {
      final freeEdge = flapBendShadowAlphaAt(0);
      expect(freeEdge, greaterThan(0.4));
      // ...and a lit trough between the two lobes, or the separate highlight
      // has nothing to sit on top of.
      expect(flapBendShadowAlphaAt(0.45), lessThan(freeEdge));
    });

    test('stays inside the unit interval and rejects out-of-range input', () {
      for (var i = 0; i <= 50; i++) {
        final u = i / 50;
        expect(
          flapBendShadowAlphaAt(u),
          inInclusiveRange(0.0, 1.0),
          reason: 'at u=$u',
        );
      }
      expect(flapBendShadowAlphaAt(-0.01), 0);
      expect(flapBendShadowAlphaAt(1.01), 0);
    });

    test('a double spread carries more bend than a single page', () {
      expect(
        flapBendShadowPeak(isPaperDark: false, isDoubleSpread: true),
        greaterThan(
          flapBendShadowPeak(isPaperDark: false, isDoubleSpread: false),
        ),
      );
    });

    test(
        'dark stock is held back — a screen blend on near-black paper '
        'carries far more perceived contrast than the same alpha of black '
        'on white', () {
      expect(
        flapBendShadowPeak(isPaperDark: true, isDoubleSpread: true),
        lessThan(flapBendShadowPeak(isPaperDark: false, isDoubleSpread: true)),
      );
    });

    test('sample stops span the full flap, uniformly', () {
      final stops = bendShadowSampleStops(12);
      expect(stops.length, 12);
      expect(stops.first, 0);
      expect(stops.last, 1);
      for (var i = 1; i < stops.length; i++) {
        expect(stops[i], greaterThan(stops[i - 1]));
      }
    });
  });
}
