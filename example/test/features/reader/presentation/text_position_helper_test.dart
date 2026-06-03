import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/text_position_helper.dart';

void main() {
  group('TextPositionHelper Tests', () {
    test('getSentenceAtOffset extracts correct sentence from middle of string', () {
      const text = 'Hello world. This is the second sentence! And the third?';

      // 1. Double tap on "world" (index 6)
      final entry1 = getSentenceAtOffset(text, 6);
      expect(entry1.key, equals(0));
      expect(entry1.value, equals('Hello world.'));

      // 2. Double tap on "second" (index 26)
      final entry2 = getSentenceAtOffset(text, 26);
      expect(entry2.key, equals(13)); // starts after space of 'Hello world. '
      expect(entry2.value, equals('This is the second sentence!'));

      // 3. Double tap on "third" (index 50)
      final entry3 = getSentenceAtOffset(text, 50);
      expect(entry3.key, equals(42));
      expect(entry3.value, equals('And the third?'));
    });

    test('getSentenceAtOffset handles empty boundaries gracefully', () {
      const text = '';
      final entry = getSentenceAtOffset(text, 0);
      expect(entry.key, equals(0));
      expect(entry.value, equals(''));
    });
  });
}
