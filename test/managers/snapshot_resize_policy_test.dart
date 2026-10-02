import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/managers/pre_render_manager.dart';

/// When may a resize keep the (debounced) recapture, and when does it need an
/// immediate one? Snapshots are drawn with `BoxFit.fill`, so what matters is a
/// change of *shape*: a stale image is stretched by exactly that ratio.
void main() {
  bool jump(Size from, Size to) =>
      PreRenderManager.resizeDistortsSnapshots(from, to);

  group('resizeDistortsSnapshots', () {
    test('an unchanged size is not a jump', () {
      expect(jump(const Size(400, 600), const Size(400, 600)), isFalse);
    });

    test('a pure scale change keeps the shape, so nothing is stretched', () {
      expect(jump(const Size(400, 600), const Size(800, 1200)), isFalse);
      expect(jump(const Size(800, 1200), const Size(400, 600)), isFalse);
    });

    test('foldable and rotation changes of shape are jumps', () {
      // Galaxy Z Fold8: cover 10:16 <-> inner 4:3 (both orientations).
      expect(jump(const Size(416, 657), const Size(816, 616)), isTrue);
      expect(jump(const Size(816, 616), const Size(416, 657)), isTrue);
      expect(jump(const Size(416, 657), const Size(616, 816)), isTrue);
      // Galaxy Z Fold8 Ultra: cover 21:9 <-> inner 10:9.
      expect(jump(const Size(360, 840), const Size(752, 835)), isTrue);
      // Any phone rotation.
      expect(jump(const Size(400, 800), const Size(800, 400)), isTrue);
    });

    test('the direction of a jump does not matter', () {
      const a = Size(300, 500);
      const b = Size(600, 500);
      expect(jump(a, b), jump(b, a));
    });

    test(
        'the small steps of a window drag or keyboard animation are not '
        'jumps', () {
      expect(jump(const Size(816, 616), const Size(819, 616)), isFalse);
      expect(jump(const Size(400, 800), const Size(400, 776)), isFalse);
      // A step that changes the shape by just under the tolerance.
      expect(jump(const Size(1000, 1000), const Size(1099, 1000)), isFalse);
    });

    test('the tolerance sits where a stretched page becomes noticeable', () {
      expect(PreRenderManager.snapshotShapeTolerance, 0.1);
      expect(jump(const Size(1000, 1000), const Size(1101, 1000)), isTrue);
      expect(jump(const Size(1101, 1000), const Size(1000, 1000)), isTrue);
    });

    test('a collapsed or unusable previous size held no snapshot', () {
      expect(jump(Size.zero, const Size(400, 600)), isTrue);
      expect(jump(const Size(0, 600), const Size(400, 600)), isTrue);
      expect(jump(const Size(400, 0), const Size(400, 600)), isTrue);
      expect(jump(const Size(double.nan, 600), const Size(400, 600)), isTrue);
      expect(
        jump(const Size(double.infinity, 600), const Size(400, 600)),
        isTrue,
      );
    });

    test('an unusable new size is never worth a capture', () {
      expect(jump(const Size(400, 600), Size.zero), isFalse);
      expect(jump(const Size(400, 600), const Size(0, 600)), isFalse);
      expect(jump(const Size(400, 600), const Size(400, 0)), isFalse);
      expect(jump(const Size(400, 600), const Size(double.nan, 600)), isFalse);
      expect(jump(Size.zero, Size.zero), isFalse);
    });

    test('is total: never throws for any pair of sizes', () {
      const values = <double>[
        0,
        1e-9,
        1,
        400,
        1000000000,
        -5,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];
      for (final fw in values) {
        for (final fh in values) {
          for (final tw in values) {
            for (final th in values) {
              expect(
                () => jump(Size(fw, fh), Size(tw, th)),
                returnsNormally,
                reason: '($fw, $fh) -> ($tw, $th)',
              );
            }
          }
        }
      }
    });
  });
}
