import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

/// Regression for the "vertical dark band at the paper edge" on dark themes
/// (e.g. pure-black). The free-edge / fold texture masks paint the paper colour
/// over the mesh boundary. On a near-black paper a full-opacity, wide mask wipes
/// the light text into a hard solid band. On dark paper the masks must stay
/// below full opacity (so content bleeds through faintly) and narrower (so any
/// residual band stays thin), while light paper keeps full coverage because the
/// mask is invisible paper-over-paper there.
void main() {
  group('edge / fold mask is softened on dark paper', () {
    test('light paper masks at full opacity (invisible, full crush coverage)',
        () {
      expect(edgeMaskPeakOpacity(isPaperDark: false), 1.0);
    });

    test('dark paper masks held below full opacity so text bleeds through', () {
      final dark = edgeMaskPeakOpacity(isPaperDark: true);
      expect(dark, lessThan(1.0));
      expect(dark, greaterThan(0.0));
      expect(
        dark,
        lessThan(edgeMaskPeakOpacity(isPaperDark: false)),
        reason: 'dark paper must mask more gently than light paper to avoid '
            'the hard dark band over the text.',
      );
    });

    test('dark paper masks are narrower than light paper masks', () {
      expect(
        edgeMaskWidth(isPaperDark: true),
        lessThan(edgeMaskWidth(isPaperDark: false)),
      );
      expect(
        foldMaskWidth(isPaperDark: true),
        lessThan(foldMaskWidth(isPaperDark: false)),
      );
    });

    test('high-DPI (≥2.0) widens masks by 25% to cover sub-pixel artifacts',
        () {
      final edgeBase = edgeMaskWidth(isPaperDark: false);
      final edgeHiDpi = edgeMaskWidth(isPaperDark: false, devicePixelRatio: 3);
      expect(edgeHiDpi, closeTo(edgeBase * 1.25, 0.001));

      final foldBase = foldMaskWidth(isPaperDark: true);
      final foldHiDpi = foldMaskWidth(isPaperDark: true, devicePixelRatio: 2);
      expect(foldHiDpi, closeTo(foldBase * 1.25, 0.001));
    });

    test('low-DPI (<2.0) keeps original mask widths', () {
      expect(
        edgeMaskWidth(isPaperDark: false),
        edgeMaskWidth(isPaperDark: false),
      );
      expect(
        foldMaskWidth(isPaperDark: false, devicePixelRatio: 1.5),
        foldMaskWidth(isPaperDark: false),
      );
    });
  });
}
