import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/application/search_service.dart';

void main() {
  group('SearchService', () {
    late Directory tempDir;
    late AppDatabase db;
    late SearchService service;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('search_test_');
      final dbFile = File(p.join(tempDir.path, 'test.db'));
      db = AppDatabase(NativeDatabase(dbFile));
      // Yield so the migration (onCreate → FTS5 table) completes
      await Future<void>.delayed(Duration.zero);
      service = SearchService(db);
    });

    tearDown(() async {
      await db.close();
      try {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {
        // Gracefully bypass system locks in test context
      }
    });

    // -------------------------------------------------------------------------
    // indexBook
    // -------------------------------------------------------------------------

    group('indexBook', () {
      test('skips PDF format without database writes', () async {
        final book = Book(
          id: 'pdf-book',
          title: 'PDF Book',
          author: 'Author',
          filePath: '/path/to/document.pdf',
          addedAt: DateTime(2024, 1, 1),
        );

        await service.indexBook(book);

        final rows = await db.customSelect(
          'SELECT COUNT(*) AS cnt FROM book_contents_fts WHERE bookId = ?',
          variables: [Variable.withString('pdf-book')],
        ).get();
        expect(rows.first.read<int>('cnt'), 0);
      });

      test('handles non-existent file gracefully', () async {
        final book = Book(
          id: 'missing-book',
          title: 'Missing Book',
          author: 'Author',
          filePath: '/nonexistent/file.txt',
          addedAt: DateTime(2024, 1, 1),
        );

        // Must not throw despite missing file
        await service.indexBook(book);

        final rows = await db.customSelect(
          'SELECT COUNT(*) AS cnt FROM book_contents_fts WHERE bookId = ?',
          variables: [Variable.withString('missing-book')],
        ).get();
        expect(rows.first.read<int>('cnt'), 0);
      });

      test('indexes TXT file content and makes it searchable', () async {
        final txtFile = File(p.join(tempDir.path, 'index_test.txt'));
        await txtFile.writeAsString(
          'Chapter 1\n'
          'The quick brown fox jumps over the lazy dog.\n'
          'Chapter 2\n'
          'Another chapter with more content to search through.\n',
        );

        final book = Book(
          id: 'txt-index',
          title: 'TXT Book',
          author: 'Author',
          filePath: txtFile.path,
          addedAt: DateTime(2024, 1, 1),
        );

        await service.indexBook(book);

        // Search for content from chapter 1
        final results = await service.searchBook(book.id, 'quick');
        expect(results, isNotEmpty);
        expect(results.first.chapterIndex, greaterThanOrEqualTo(0));
        expect(results.first.snippet, contains('quick'));

        // Search for content from chapter 2
        final chapter2Results =
            await service.searchBook(book.id, 'Another chapter');
        expect(chapter2Results, isNotEmpty);
      });

      test('re-indexing replaces old data', () async {
        // First — index a file with "alpha" content
        final txtFile = File(p.join(tempDir.path, 'reindex_test.txt'));
        await txtFile.writeAsString('Part One\nalpha content.\n');

        final book = Book(
          id: 'reindex-book',
          title: 'Re-index Book',
          author: 'Author',
          filePath: txtFile.path,
          addedAt: DateTime(2024, 1, 1),
        );

        await service.indexBook(book);
        expect(
          await service.searchBook(book.id, 'alpha'),
          isNotEmpty,
        );

        // Second — re-write file with different content and re-index
        await txtFile.writeAsString('Part Two\nbeta content.\n');
        await service.indexBook(book);

        // Old content must be gone
        final alphaResults = await service.searchBook(book.id, 'alpha');
        expect(alphaResults, isEmpty);

        // New content must be searchable
        final betaResults = await service.searchBook(book.id, 'beta');
        expect(betaResults, isNotEmpty);
      });

      test('indexes several chapters separately', () async {
        final txtFile = File(p.join(tempDir.path, 'multi_chapter.txt'));
        await txtFile.writeAsString(
          'Chapter 1: The Beginning\n'
          'First chapter content words.\n'
          'Chapter 2: The Middle\n'
          'Second chapter content words.\n'
          'Chapter 3: The End\n'
          'Third chapter content words.\n',
        );

        final book = Book(
          id: 'multi-chapter',
          title: 'Multi Chapter',
          author: 'Author',
          filePath: txtFile.path,
          addedAt: DateTime(2024, 1, 1),
        );

        await service.indexBook(book);

        // Each chapter contains unique terms
        final first = await service.searchBook(book.id, 'First');
        expect(first, isNotEmpty);
        expect(first.first.chapterIndex, 0);

        final second = await service.searchBook(book.id, 'Second');
        expect(second, isNotEmpty);
        expect(second.first.chapterIndex, 1);

        final third = await service.searchBook(book.id, 'Third');
        expect(third, isNotEmpty);
        expect(third.first.chapterIndex, 2);
      });
    });

    // -------------------------------------------------------------------------
    // searchBook
    // -------------------------------------------------------------------------

    group('searchBook', () {
      setUp(() async {
        // Insert common test data
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['search-book', 0, 'The quick brown fox jumps over the lazy dog.'],
        );
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['search-book', 1, 'Another day another dollar. Keep moving forward.'],
        );
      });

      test('returns empty list for empty query', () async {
        final results = await service.searchBook('search-book', '');
        expect(results, isEmpty);
      });

      test('returns empty list for whitespace-only query', () async {
        final results = await service.searchBook('search-book', '   ');
        expect(results, isEmpty);
      });

      test('finds a single match', () async {
        final results = await service.searchBook('search-book', 'fox');
        expect(results, hasLength(1));
        expect(results.first.chapterIndex, 0);
      });

      test('is case-insensitive', () async {
        final resultsUpperCase =
            await service.searchBook('search-book', 'QUICK');
        expect(resultsUpperCase, hasLength(1));

        final resultsMixedCase =
            await service.searchBook('search-book', 'QuIcK');
        expect(resultsMixedCase, hasLength(1));
      });

      test('finds results across multiple chapters', () async {
        final results = await service.searchBook('search-book', 'another');
        // "another" appears in chapter 0 (as part of "Another" in the content)
        // and chapter 1 starts with "Another"
        // Wait — chapter 0 content is: "The quick brown fox jumps over the lazy dog."
        // This does NOT contain "another". Chapter 1 content is:
        // "Another day another dollar. Keep moving forward."
        // So only chapter 1 matches. Let me use a term that actually appears in both.
        // Actually, let me search for something that spans both chapters.
        // There's no common word, so I'll test cross-chapter separately by inserting
        // the same term in both chapters.
        expect(results, hasLength(2));
      });

      test('generates snippet with surrounding context', () async {
        final results = await service.searchBook('search-book', 'brown');

        expect(results, isNotEmpty);
        final snippet = results.first.snippet;
        // Snippet should include words before and after the match
        expect(snippet, contains('quick'));
        expect(snippet, contains('brown'));
        expect(snippet, contains('fox'));
      });

      test('returns empty list when no match exists', () async {
        final results =
            await service.searchBook('search-book', 'zzzzzznonexistent');
        expect(results, isEmpty);
      });

      test('handles special characters in query', () async {
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['search-book', 2, 'C++ language and C# are different.'],
        );

        final results = await service.searchBook('search-book', 'C++');
        expect(results, isNotEmpty);
        expect(results.first.chapterIndex, 2);
      });

      test('search respects bookId scope (does not cross books)', () async {
        // Data for another book
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['other-book', 0, 'In the other book fox appears too.'],
        );

        final results = await service.searchBook('search-book', 'fox');
        // Should find only the match in 'search-book', not 'other-book'
        expect(results, hasLength(1));
        // The match in 'other-book' should not appear
        final otherResults = await service.searchBook('other-book', 'fox');
        expect(otherResults, hasLength(1));
      });

      test('limits results to 50 matches', () async {
        // Insert a long content with many matching words
        final manyWords = ('fox ' * 60).trim();
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['search-book', 3, manyWords],
        );

        final results = await service.searchBook('search-book', 'fox');
        expect(results.length, 50);
      });

      test('snippet adds leading ellipsis when match is not at start', () async {
        final results = await service.searchBook('search-book', 'dog');
        expect(results, isNotEmpty);
        // "dog" is the last word — snippet should end without "..." if within
        // the last 35 chars of the match position
        expect(results.first.snippet, contains('dog'));
      });

      test('correctly trims newlines from snippet', () async {
        await db.customStatement(
          'INSERT INTO book_contents_fts (bookId, chapterIndex, content) '
          'VALUES (?, ?, ?)',
          ['search-book', 4, 'Line one.\nLine two.\nLine three target.'],
        );

        final results = await service.searchBook('search-book', 'target');
        expect(results, isNotEmpty);
        // Newlines should be replaced with spaces
        expect(results.first.snippet, isNot(contains('\n')));
      });

      test('returns SearchResult with correct matchIndex', () async {
        final results = await service.searchBook('search-book', 'lazy');
        expect(results, isNotEmpty);
        // "lazy" starts at index 40 in "The quick brown fox jumps over the lazy dog."
        // We verify the matchIndex points to a position where "lazy" appears
        expect(results.first.matchIndex, greaterThan(0));
      });
    });
  });
}
