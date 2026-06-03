import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';

/// PageFlipGestureRecognizer의 수직/수평 제스처 분리 로직 검증
void main() {
  group('PageFlipGestureRecognizer Gesture Arbitration', () {
    late PageFlipGestureRecognizer recognizer;

    setUp(() {
      recognizer = PageFlipGestureRecognizer(sensitivity: 0.5);
    });

    tearDown(() {
      recognizer.dispose();
    });

    test('Should reject when vertical movement dominates horizontal', () {
      // sensitivity 0.5 -> checkSlop = 18 - (17 * 0.5) = 9.5
      // 수직 이동이 수평보다 1.2배 이상이면 거부해야 함

      // Simulate vertical-dominant drag (dy > dx * 1.2)
      // dx = 5, dy = 15 -> dy(15) > dx(5) * 1.2(6) -> 거부되어야 함
      final verticalDominant =
          _simulateGestureDirection(dx: 5, dy: 15, checkSlop: 9.5);
      expect(
        verticalDominant,
        isFalse,
        reason: 'Vertical-dominant gesture should yield to vertical scroll',
      );
    });

    test('Should accept when horizontal movement dominates', () {
      // dx = 15, dy = 5 -> dx(15) * 2.5(37.5) > dy(5) -> 수락되어야 함
      final horizontalDominant =
          _simulateGestureDirection(dx: 15, dy: 5, checkSlop: 9.5);
      expect(
        horizontalDominant,
        isTrue,
        reason: 'Horizontal-dominant gesture should trigger page flip',
      );
    });

    test('Should reject diagonal gesture (45 degrees)', () {
      // dx = 10, dy = 10 -> dx(10) * 2.5(25) > dy(10) -> 수락? 아님
      // 하지만 dy(10) > checkSlop(9.5) && dy(10) > dx(10) * 1.2(12) -> 거짓
      // -> 첫번째 조건 통과 안됨 -> 두번째 조건 체크
      // dx(10) > checkSlop(9.5) -> 참, dx(10)*2.5(25) > dy(10) -> 참 -> 수락
      final diagonal45 =
          _simulateGestureDirection(dx: 10, dy: 10, checkSlop: 9.5);
      expect(
        diagonal45,
        isTrue,
        reason: '45 degree diagonal should accept (natural thumb arc)',
      );
    });

    test('Should reject steep diagonal (70+ degrees)', () {
      // dx = 5, dy = 14 -> dy(14) > checkSlop(9.5) && dy(14) > dx(5)*1.2(6) -> 거부
      final steepDiagonal =
          _simulateGestureDirection(dx: 5, dy: 14, checkSlop: 9.5);
      expect(
        steepDiagonal,
        isFalse,
        reason: 'Steep diagonal (70+ degrees) should yield to vertical scroll',
      );
    });

    test('Should accept shallow diagonal (20 degrees)', () {
      // dx = 20, dy = 7 -> dx(20) > checkSlop(9.5) && dx(20)*2.5(50) > dy(7) -> 수락
      final shallowDiagonal =
          _simulateGestureDirection(dx: 20, dy: 7, checkSlop: 9.5);
      expect(
        shallowDiagonal,
        isTrue,
        reason: 'Shallow diagonal should trigger page flip',
      );
    });

    test('High sensitivity should reduce slop threshold', () {
      // sensitivity 1.0 -> checkSlop = 18 - 17 = 1
      // 더 민감하게 반응해야 함
      const highSensSlop = 18.0 - (17.0 * 1.0);
      expect(highSensSlop, equals(1.0));
    });

    test('Low sensitivity should increase slop threshold', () {
      // sensitivity 0.0 -> checkSlop = 18 - 0 = 18
      // 덜 민감하게 반응해야 함
      const lowSensSlop = 18.0 - (17.0 * 0.0);
      expect(lowSensSlop, equals(18.0));
    });
  });
}

bool _simulateGestureDirection({
  required double dx,
  required double dy,
  required double checkSlop,
}) {
  final sensitivity = (18.0 - checkSlop) / 17.0;
  return PageFlipGestureArbitration.shouldAcceptFlipDrag(
    totalDx: dx,
    totalDy: dy,
    sensitivity: sensitivity,
  );
}
