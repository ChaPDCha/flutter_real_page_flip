import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:real_page_flip_example/features/bookshelf/data/drift_book_repository.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DriftBookRepository', () {
    late Directory tempDir;
    late AppDatabase db;
    late DriftBookRepository repository;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('drift_repo_test');
    });

    tearDown(() async {
      await db.close();
      try {
        if (tempDir.existsSync()) {
          await Future.delayed(const Duration(milliseconds: 150));
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {
        // Gracefully bypass system locks in test context
      }
    });

    Future<void> createRepository() async {
      final dbFile = File(p.join(tempDir.path, 'test.db'));
      db = AppDatabase(NativeDatabase(dbFile));
      repository = DriftBookRepository(db);
    }

    Book createBook({
      String id = 'book-1',
      String title = 'Test Book',
      String author = 'Test Author',
      String filePath = '/path/to/test.epub',
      String? coverImagePath,
    }) {
      return Book(
        id: id,
        title: title,
        author: author,
        filePath: filePath,
        coverImagePath: coverImagePath,
        addedAt: DateTime(2026, 6, 1),
      );
    }

    group('empty state', () {
      test('getBooks returns empty list when no books exist', () async {
        await createRepository();

        final books = await repository.getBooks();

        expect(books, isEmpty);
      });
    });

    group('addBook', () {
      test('adds a single book and retrieves it', () async {
        await createRepository();
        final book = createBook();

        await repository.addBook(book);

        final books = await repository.getBooks();
        expect(books.length, 1);
        expect(books.first.id, 'book-1');
        expect(books.first.title, 'Test Book');
        expect(books.first.author, 'Test Author');
        expect(books.first.filePath, '/path/to/test.epub');
        expect(books.first.addedAt, DateTime(2026, 6, 1));
      });

      test('adds multiple books and retrieves all', () async {
        await createRepository();
        final book1 = createBook(id: 'book-1', title: 'Book One', filePath: '/path/book1.epub');
        final book2 = createBook(id: 'book-2', title: 'Book Two', filePath: '/path/book2.epub');
        final book3 = createBook(id: 'book-3', title: 'Book Three', filePath: '/path/book3.epub');

        await repository.addBook(book1);
        await repository.addBook(book2);
        await repository.addBook(book3);

        final books = await repository.getBooks();
        expect(books.length, 3);
        expect(books.map((b) => b.id), containsAll(['book-1', 'book-2', 'book-3']));
      });

      test('updates existing book with same ID (upsert behavior)', () async {
        await createRepository();
        final book1 = createBook(title: 'Original Title');
        await repository.addBook(book1);

        final book1Updated = createBook(title: 'Updated Title');
        await repository.addBook(book1Updated);

        final books = await repository.getBooks();
        expect(books.length, 1);
        expect(books.first.title, 'Updated Title');
      });

      test('book with cover image path stores and retrieves correctly', () async {
        await createRepository();
        final book = createBook(
          coverImagePath: '/path/to/cover.png',
        );

        await repository.addBook(book);

        final books = await repository.getBooks();
        expect(books.first.coverImagePath, '/path/to/cover.png');
      });

      test('book with null cover image path is stored correctly', () async {
        await createRepository();
        final book = createBook(coverImagePath: null);

        await repository.addBook(book);

        final books = await repository.getBooks();
        expect(books.first.coverImagePath, isNull);
      });

      test('stores book with different file extensions', () async {
        await createRepository();

        final epubBook = createBook(id: 'epub-book', filePath: '/path/book.epub');
        final txtBook = createBook(id: 'txt-book', filePath: '/path/book.txt');

        await repository.addBook(epubBook);
        await repository.addBook(txtBook);

        final books = await repository.getBooks();
        expect(books.length, 2);
      });
    });

    group('removeBook', () {
      test('removes an existing book', () async {
        await createRepository();
        final book = createBook();
        await repository.addBook(book);

        var books = await repository.getBooks();
        expect(books.length, 1);

        await repository.removeBook('book-1');

        books = await repository.getBooks();
        expect(books, isEmpty);
      });

      test('removing a non-existent book does not throw', () async {
        await createRepository();

        await repository.removeBook('non-existent-id');

        // Should not throw and state remains empty
        final books = await repository.getBooks();
        expect(books, isEmpty);
      });

      test('removes specific book without affecting others', () async {
        await createRepository();
        final book1 = createBook(id: 'book-1', title: 'Book One', filePath: '/path/one.epub');
        final book2 = createBook(id: 'book-2', title: 'Book Two', filePath: '/path/two.epub');
        await repository.addBook(book1);
        await repository.addBook(book2);

        await repository.removeBook('book-1');

        final books = await repository.getBooks();
        expect(books.length, 1);
        expect(books.first.id, 'book-2');
      });
    });

    group('getBooks ordering', () {
      test('returns books in insertion order', () async {
        await createRepository();

        await repository.addBook(createBook(id: 'a', title: 'Alpha', filePath: '/path/a.epub'));
        await repository.addBook(createBook(id: 'b', title: 'Beta', filePath: '/path/b.epub'));
        await repository.addBook(createBook(id: 'c', title: 'Gamma', filePath: '/path/c.epub'));

        final books = await repository.getBooks();
        expect(books.length, 3);
        expect(books[0].id, 'a');
        expect(books[1].id, 'b');
        expect(books[2].id, 'c');
      });
    });

    group('edge cases', () {
      test('handles books with special characters in fields', () async {
        await createRepository();
        final book = createBook(
          id: 'special-id',
          title: 'Book with spécial chàracters!',
          author: 'Author Name 123',
        );

        await repository.addBook(book);

        final books = await repository.getBooks();
        expect(books.first.title, 'Book with spécial chàracters!');
        expect(books.first.author, 'Author Name 123');
      });

      test('handles very long file paths', () async {
        await createRepository();
        final longPath = '/path/${'a' * 200}/book.epub';
        final book = createBook(filePath: longPath);

        await repository.addBook(book);

        final books = await repository.getBooks();
        expect(books.first.filePath, longPath);
      });
    });
  });
}
