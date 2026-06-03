import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

void main() {
  group('PageFlipSpreadMode', () {
    test('fromIsDoubleSpread maps legacy bool', () {
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(true),
        PageFlipSpreadMode.doubleSpread,
      );
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(false),
        PageFlipSpreadMode.single,
      );
    });

    test('isDoubleSpread getter matches mode', () {
      expect(PageFlipSpreadMode.single.isDoubleSpread, isFalse);
      expect(PageFlipSpreadMode.doubleSpread.isDoubleSpread, isTrue);
    });
  });
}
