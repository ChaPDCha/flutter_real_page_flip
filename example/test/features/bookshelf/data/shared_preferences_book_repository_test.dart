import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/bookshelf/data/shared_preferences_book_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesBookRepository Tests', () {
    late SharedPreferencesBookRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = SharedPreferencesBookRepository();
    });

    test('getBooks returns empty list initially', () async {
      final books = await repository.getBooks();
      expect(books, isEmpty);
    });

    test('addBook saves a book successfully and can be retrieved', () async {
      final book = Book(
        id: 'test_id',
        title: 'Test Title',
        author: 'Test Author',
        filePath: '/path/to/test.epub',
        coverImagePath: '/path/to/cover.png',
        addedAt: DateTime.now(),
      );

      await repository.addBook(book);

      final books = await repository.getBooks();
      expect(books.length, equals(1));
      expect(books.first.id, equals('test_id'));
      expect(books.first.title, equals('Test Title'));
      expect(books.first.author, equals('Test Author'));
    });

    test('addBook overwrites/replaces duplicate book instead of duplicating in list', () async {
      final book1 = Book(
        id: 'test_id',
        title: 'Title V1',
        author: 'Author',
        filePath: '/path/to/v1.epub',
        addedAt: DateTime.now(),
      );

      final book2 = Book(
        id: 'test_id',
        title: 'Title V2', // Same ID, new metadata
        author: 'Author',
        filePath: '/path/to/v2.epub',
        addedAt: DateTime.now(),
      );

      await repository.addBook(book1);
      await repository.addBook(book2);

      final books = await repository.getBooks();
      expect(books.length, equals(1));
      expect(books.first.title, equals('Title V2'));
    });

    test('removeBook deletes the book from list', () async {
      final book = Book(
        id: 'delete_id',
        title: 'To Be Deleted',
        author: 'Author',
        filePath: '/path/to/delete.epub',
        addedAt: DateTime.now(),
      );

      await repository.addBook(book);
      
      var books = await repository.getBooks();
      expect(books.length, equals(1));

      await repository.removeBook('delete_id');
      
      books = await repository.getBooks();
      expect(books, isEmpty);
    });
  });
}
