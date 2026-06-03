import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/domain/reader_settings.dart';

void main() {
  group('ReaderSettings Domain Model Tests', () {
    test('ReaderSettings has correct default values', () {
      const settings = ReaderSettings();
      expect(settings.fontSize, equals(16.0));
      expect(settings.lineHeight, equals(1.6));
      expect(settings.enableHaptics, isTrue);
      expect(settings.enableSound, isTrue);
    });

    test('ReaderSettings JSON serialization and deserialization matches', () {
      const settings = ReaderSettings(
        fontSize: 20.0,
        lineHeight: 1.6,
        enableHaptics: false,
        enableSound: false,
      );

      final jsonMap = settings.toJson();
      expect(jsonMap['fontSize'], equals(20.0));
      expect(jsonMap.containsKey('themeType'), isFalse);

      final deserialized = ReaderSettings.fromJson(jsonMap);
      expect(deserialized, equals(settings));
    });
  });
}
