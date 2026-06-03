import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';

void main() {
  group('Book Domain Model Tests', () {
    test('Book JSON serialization and deserialization matches', () {
      final now = DateTime.now();
      final book = Book(
        id: '123',
        title: 'Title',
        author: 'Author',
        filePath: '/path/to/book',
        coverImagePath: '/path/to/cover',
        addedAt: now,
      );

      final jsonMap = book.toJson();
      expect(jsonMap['id'], equals('123'));
      expect(jsonMap['title'], equals('Title'));
      expect(jsonMap['addedAt'], equals(now.toIso8601String()));

      final deserialized = Book.fromJson(jsonMap);
      expect(deserialized, equals(book));
      expect(deserialized.id, equals('123'));
      expect(deserialized.addedAt, equals(now));
    });
  });
}
