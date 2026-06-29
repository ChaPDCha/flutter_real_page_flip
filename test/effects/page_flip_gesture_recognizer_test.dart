import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipGestureRecognizer', () {
    const pointerId = 1;
    const defaultSlop = 9.5; // 18 - 17*0.5

    void feedPointerDown(PageFlipGestureRecognizer r) {
      r.addAllowedPointer(
        const PointerDownEvent(
          pointer: pointerId,
        ),
      );
    }

    void feedMove(PageFlipGestureRecognizer r, Offset delta) {
      r.handleEvent(
        PointerMoveEvent(
          pointer: pointerId,
          position: delta,
          delta: delta,
        ),
      );
    }

    bool hasSufficient(PageFlipGestureRecognizer r) =>
        r.hasSufficientGlobalDistanceToAccept(
          PointerDeviceKind.touch,
          defaultSlop,
        );

    testWidgets(
        'yields to vertical scroll when movement is predominantly vertical',
        (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(0, 20));
      expect(hasSufficient(r), isFalse);
    });

    testWidgets('accepts when movement is predominantly horizontal',
        (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(20, 0));
      expect(hasSufficient(r), isTrue);
    });

    testWidgets('yields when vertical dominant diagonal (dy > dx*1.2)',
        (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(5, 15));
      expect(hasSufficient(r), isFalse);
    });

    testWidgets('accepts when horizontal dominant diagonal (dx*2.5 > dy)',
        (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(15, 5));
      expect(hasSufficient(r), isTrue);
    });

    testWidgets('rejects when below slop (ambiguous)', (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(5, 5));
      expect(hasSufficient(r), isFalse);
    });

    testWidgets('accumulates multiple move deltas', (tester) async {
      final r = PageFlipGestureRecognizer();
      feedPointerDown(r);
      feedMove(r, const Offset(2, 0));
      feedMove(r, const Offset(2, 0));
      feedMove(r, const Offset(2, 0));
      feedMove(r, const Offset(2, 0));
      feedMove(r, const Offset(2, 0));
      feedMove(r, const Offset(2, 0));
      expect(hasSufficient(r), isTrue);
    });
  });
}
