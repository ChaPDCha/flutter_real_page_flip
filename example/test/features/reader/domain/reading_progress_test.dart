import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/domain/reading_progress.dart';

void main() {
  group('ReadingProgress Domain Model Tests', () {
    test('ReadingProgress JSON serialization and deserialization matches', () {
      final now = DateTime.now();
      final progress = ReadingProgress(
        bookId: 'test_book',
        chapterIndex: 3,
        pageIndex: 5,
        lastReadAt: now,
      );

      final jsonMap = progress.toJson();
      expect(jsonMap['bookId'], equals('test_book'));
      expect(jsonMap['chapterIndex'], equals(3));
      expect(jsonMap['pageIndex'], equals(5));

      final deserialized = ReadingProgress.fromJson(jsonMap);
      expect(deserialized, equals(progress));
    });
  });
}
