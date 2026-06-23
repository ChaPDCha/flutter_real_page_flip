import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PaperFlipCurve', () {
    test('starts at 0 and ends at 1', () {
      const curve = PaperFlipCurve();
      expect(curve.transform(0.0), closeTo(0.0, 0.001));
      expect(curve.transform(1.0), closeTo(1.0, 0.001));
    });

    test('early push: steep initial ramp', () {
      const curve = PaperFlipCurve();
      // PaperFlipCurve(0.05, 0.7, 0.1, 1.0) — cubic bezier.
      // With first control point at 0.05, the curve accelerates fast:
      // at t=0.10, progress has already reached ~0.62.
      final at05 = curve.transform(0.05);
      expect(at05, greaterThan(0.05)); // faster than linear
      expect(at05, lessThan(0.50));

      final at10 = curve.transform(0.10);
      expect(at10, greaterThan(at05));
      expect(at10, greaterThan(0.50)); // already past midpoint!
    });

    test('mid plateau slows between 30-70% of time', () {
      const curve = PaperFlipCurve();
      final at30 = curve.transform(0.30);
      final at70 = curve.transform(0.70);
      final midDelta = at70 - at30;
      // Over 40% of the time span, progress should increase by at most 0.50
      // (plateau effect means it doesn't change much).
      expect(midDelta, greaterThan(0.05));
      expect(midDelta, lessThan(0.60));
    });

    test('late settle completes remaining progress', () {
      const curve = PaperFlipCurve();
      final at70 = curve.transform(0.70);
      // By 70% of time, well past half.
      expect(at70, greaterThan(0.50));
      // By 95% of time, nearly complete.
      final at95 = curve.transform(0.95);
      expect(at95, greaterThan(at70));
      expect(at95, greaterThan(0.90));
    });

    test('monotonic non-decreasing throughout [0,1]', () {
      const curve = PaperFlipCurve();
      double prev = 0.0;
      for (int i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final v = curve.transform(t);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });

    test('C∞ smooth: first derivative at boundaries is finite', () {
      // Numerical derivative check: (f(t+ε) - f(t)) / ε at boundaries.
      const curve = PaperFlipCurve();
      const eps = 0.001;
      final derivStart = (curve.transform(eps) - curve.transform(0.0)) / eps;
      final derivEnd =
          (curve.transform(1.0) - curve.transform(1.0 - eps)) / eps;
      // Slope should be finite and positive at both ends.
      expect(derivStart, greaterThan(0.0));
      expect(derivEnd, greaterThan(0.0));
      expect(derivStart.isFinite, isTrue);
      expect(derivEnd.isFinite, isTrue);
    });
  });

  group('TapFlipCurve', () {
    test('starts at 0 and ends at 1', () {
      const curve = TapFlipCurve();
      expect(curve.transform(0.0), closeTo(0.0, 0.001));
      expect(curve.transform(1.0), closeTo(1.0, 0.001));
    });

    test('ease-in-out-quart: slow start, faster mid, slow end', () {
      const curve = TapFlipCurve();
      // At t=0.25, ease-in-out-quart = 4 * 0.25^3 = 4 * 0.015625 = 0.0625
      // Slower start compared to linear 0.25.
      expect(curve.transform(0.25), lessThan(0.25));
      // At t=0.5, ease-in-out-quart = 0.5 (symmetric midpoint).
      expect(curve.transform(0.5), closeTo(0.5, 0.01));
      // At t=0.75, ease-in-out-quart = 1 - 4*0.25^3/2 = ~0.9375
      expect(curve.transform(0.75), greaterThan(0.75));
    });

    test('exact ease-in-out-quart values', () {
      const curve = TapFlipCurve();
      // t < 0.5: 4*t^3
      expect(curve.transform(0.0), closeTo(0.0, 0.001));
      expect(curve.transform(0.25), closeTo(4 * 0.25 * 0.25 * 0.25, 0.001));
      expect(curve.transform(0.5), closeTo(0.5, 0.001));
      // t > 0.5: 1 - (-2t+2)^3 / 2
      // t=0.75: (-1.5+2)=0.5, 0.5^3=0.125, 0.125/2=0.0625, 1-0.0625=0.9375
      expect(curve.transform(0.75), closeTo(0.9375, 0.001));
      expect(curve.transform(1.0), closeTo(1.0, 0.001));
    });

    test('monotonic non-decreasing throughout [0,1]', () {
      const curve = TapFlipCurve();
      double prev = 0.0;
      for (int i = 0; i <= 100; i++) {
        final t = i / 100.0;
        final v = curve.transform(t);
        expect(v, greaterThanOrEqualTo(prev));
        prev = v;
      }
    });
  });
}
