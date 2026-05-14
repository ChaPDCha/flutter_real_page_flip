import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

void main() {
  group('PageFlipPainter', () {
    test('shouldRepaint returns true when progress changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns false when nothing changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint returns true when touchOffset changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset(10, 0),
        paperBackColor: Colors.white,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    test('shouldRepaint returns true when paperBackColor changes', () {
      final painter1 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.white,
      );
      final painter2 = PageFlipPainter(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
        paperBackColor: Colors.black,
      );
      expect(painter1.shouldRepaint(painter2), isTrue);
    });
  });

  group('PageFlipClipper', () {
    test('shouldReclip returns true when progress changes', () {
      final clipper = PageFlipClipper(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipClipper(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });

    test('shouldReclip returns false when progress and touchOffset are same', () {
      final clipper = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipClipper(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isFalse);
    });
  });

  group('PageFlipOpenClipper', () {
    test('shouldReclip returns true when progress changes', () {
      final clipper = PageFlipOpenClipper(
        progress: 0.3,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      final clipper2 = PageFlipOpenClipper(
        progress: 0.7,
        isRightToLeft: true,
        touchOffset: Offset.zero,
      );
      expect(clipper.shouldReclip(clipper2), isTrue);
    });
  });
}
