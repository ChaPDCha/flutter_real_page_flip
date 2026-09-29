// The web plugin imports dart:js_interop / package:web, which only compile
// for the browser. Run with: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:real_page_flip/src/web/real_page_flip_web.dart';

void main() {
  test('web plugin registers its sound channel', () {
    expect(
      () => RealPageFlipWeb.registerWith(webPluginRegistrar),
      returnsNormally,
    );
  });
}
