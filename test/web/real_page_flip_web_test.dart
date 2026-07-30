import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/web/real_page_flip_web.dart';

void main() {
  test('web plugin exposes the generated registration entry point', () {
    expect(
      () => RealPageFlipWeb.registerWith(Object()),
      returnsNormally,
    );
  });
}
