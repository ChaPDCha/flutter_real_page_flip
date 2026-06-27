import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:real_page_flip_example/features/sync/data/drift_sync_repository.dart';

void main() {
  late AppDatabase db;
  late DriftSyncRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftSyncRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // getLocalBooksDelta
  // ===========================================================================

  group('getLocalBooksDelta', () {
    test('returns books updated after the given timestamp', () async {
      final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
              updatedAt: Value(updatedAt),
            ),
          );

      final since = updatedAt.subtract(const Duration(hours: 1));
      final deltas = await repo.getLocalBooksDelta(since);

      expect(deltas.length, 1);
      expect(deltas.first['id'], 'book-1');
      expect(deltas.first['title'], 'Test Book');
      expect(deltas.first['author'], 'Test Author');
      expect(deltas.first['format'], 'epub');
      expect(deltas.first['is_deleted'], false);
    });

    test('returns empty list when no book was updated after since', () async {
      final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
              updatedAt: Value(updatedAt),
            ),
          );

      final since = updatedAt.add(const Duration(hours: 1));
      final deltas = await repo.getLocalBooksDelta(since);

      expect(deltas, isEmpty);
    });

    test('returns multiple books updated after since', () async {
      final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Book One',
              author: 'Author One',
              filePath: '/path/one.epub',
              format: 'epub',
              updatedAt: Value(updatedAt),
            ),
          );
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-2',
              title: 'Book Two',
              author: 'Author Two',
              filePath: '/path/two.epub',
              format: 'pdf',
              updatedAt: Value(updatedAt),
            ),
          );

      final since = updatedAt.subtract(const Duration(hours: 1));
      final deltas = await repo.getLocalBooksDelta(since);

      expect(deltas.length, 2);
    });

    test('handles book with null updatedAt by using current time', () async {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );

      final since = DateTime(2020, 1, 1).toUtc();
      final deltas = await repo.getLocalBooksDelta(since);

      // Book was inserted without updatedAt, so it's null.
      // The query filters by updatedAt > since, which fails for null.
      expect(deltas, isEmpty);
    });
  });

  // ===========================================================================
  // getLocalHighlightsDelta
  // ===========================================================================

  group('getLocalHighlightsDelta', () {
    test('returns highlights updated after the given timestamp', () async {
      // Need a book for FK constraint
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );

      final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
      await db
          .into(db.highlights)
          .insert(
            HighlightsCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 0,
              startOffset: 10,
              endOffset: 20,
              selectedText: 'highlighted text',
              highlightColor: 'yellow',
              updatedAt: Value(updatedAt),
            ),
          );

      final since = updatedAt.subtract(const Duration(hours: 1));
      final deltas = await repo.getLocalHighlightsDelta(since);

      expect(deltas.length, 1);
      expect(deltas.first['book_id'], 'book-1');
      expect(deltas.first['selected_text'], 'highlighted text');
      expect(deltas.first['highlight_color'], 'yellow');
      expect(deltas.first['chapter_index'], 0);
      expect(deltas.first['start_offset'], 10);
      expect(deltas.first['end_offset'], 20);
    });

    test(
      'returns empty list when no highlight was updated after since',
      () async {
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: 'book-1',
                title: 'Test Book',
                author: 'Test Author',
                filePath: '/path/book.epub',
                format: 'epub',
              ),
            );

        final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
        await db
            .into(db.highlights)
            .insert(
              HighlightsCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                startOffset: 10,
                endOffset: 20,
                selectedText: 'text',
                highlightColor: 'yellow',
                updatedAt: Value(updatedAt),
              ),
            );

        final since = updatedAt.add(const Duration(hours: 1));
        final deltas = await repo.getLocalHighlightsDelta(since);

        expect(deltas, isEmpty);
      },
    );

    test('includes note and is_deleted when present', () async {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );

      final updatedAt = DateTime(2024, 6, 15).toUtc();
      await db
          .into(db.highlights)
          .insert(
            HighlightsCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 1,
              startOffset: 5,
              endOffset: 15,
              selectedText: 'deleted highlight',
              highlightColor: 'green',
              note: const Value('my note'),
              updatedAt: Value(updatedAt),
              isDeleted: const Value(true),
            ),
          );

      final since = updatedAt.subtract(const Duration(hours: 1));
      final deltas = await repo.getLocalHighlightsDelta(since);

      expect(deltas.length, 1);
      expect(deltas.first['note'], 'my note');
      expect(deltas.first['is_deleted'], true);
    });
  });

  // ===========================================================================
  // getLocalBookmarksDelta
  // ===========================================================================

  group('getLocalBookmarksDelta', () {
    test('returns bookmarks updated after the given timestamp', () async {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );

      final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 0,
              pageIndex: 5,
              label: 'My Bookmark',
              updatedAt: Value(updatedAt),
            ),
          );

      final since = updatedAt.subtract(const Duration(hours: 1));
      final deltas = await repo.getLocalBookmarksDelta(since);

      expect(deltas.length, 1);
      expect(deltas.first['book_id'], 'book-1');
      expect(deltas.first['chapter_index'], 0);
      expect(deltas.first['page_index'], 5);
      expect(deltas.first['label'], 'My Bookmark');
    });

    test(
      'returns empty list when no bookmark was updated after since',
      () async {
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: 'book-1',
                title: 'Test Book',
                author: 'Test Author',
                filePath: '/path/book.epub',
                format: 'epub',
              ),
            );

        final updatedAt = DateTime(2024, 6, 15, 10, 0, 0).toUtc();
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                pageIndex: 5,
                label: 'My Bookmark',
                updatedAt: Value(updatedAt),
              ),
            );

        final since = updatedAt.add(const Duration(hours: 1));
        final deltas = await repo.getLocalBookmarksDelta(since);

        expect(deltas, isEmpty);
      },
    );

    test(
      'handles bookmark with null updatedAt by using current time',
      () async {
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: 'book-1',
                title: 'Test Book',
                author: 'Test Author',
                filePath: '/path/book.epub',
                format: 'epub',
              ),
            );

        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                pageIndex: 5,
                label: 'No Timestamp',
              ),
            );

        final since = DateTime(2020, 1, 1).toUtc();
        final deltas = await repo.getLocalBookmarksDelta(since);

        // Bookmark inserted without updatedAt, so it's null.
        // The query filters by updatedAt > since, which fails for null.
        expect(deltas, isEmpty);
      },
    );
  });

  // ===========================================================================
  // mergeRemoteBooks (LWW conflict resolution)
  // ===========================================================================

  group('mergeRemoteBooks', () {
    test(
      'inserts new book from remote data when local does not exist',
      () async {
        final remoteBook = {
          'id': 'remote-1',
          'title': 'Remote Book',
          'author': 'Remote Author',
          'file_path': '/remote/path.epub',
          'cover_path': null,
          'format': 'epub',
          'added_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'last_read_chapter_index': 0,
          'last_read_page_index': 0,
          'is_deleted': false,
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
        };

        await repo.mergeRemoteBooks([remoteBook]);

        final rows = await db.select(db.books).get();
        expect(rows.length, 1);
        expect(rows.first.id, 'remote-1');
        expect(rows.first.title, 'Remote Book');
        expect(rows.first.author, 'Remote Author');
        expect(rows.first.filePath, '/remote/path.epub');
        expect(rows.first.format, 'epub');
        expect(rows.first.coverPath, isNull);
      },
    );

    test(
      'updates existing book when remote timestamp is newer (LWW)',
      () async {
        final localUpdatedAt = DateTime(2024, 6, 15).toUtc();
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                id: 'book-1',
                title: 'Original Title',
                author: 'Original Author',
                filePath: '/path/book.epub',
                format: 'epub',
                updatedAt: Value(localUpdatedAt),
              ),
            );

        final remoteBook = {
          'id': 'book-1',
          'title': 'Updated Title',
          'author': 'Updated Author',
          'file_path': '/path/book.epub',
          'cover_path': 'new_cover.jpg',
          'format': 'epub',
          'added_at': DateTime(2024, 6, 14).toUtc().toIso8601String(),
          'last_read_chapter_index': 3,
          'last_read_page_index': 42,
          'is_deleted': false,
          'updated_at': DateTime(
            2024,
            6,
            16,
          ).toUtc().toIso8601String(), // newer
        };

        await repo.mergeRemoteBooks([remoteBook]);

        final rows = await db.select(db.books).get();
        expect(rows.length, 1);
        expect(rows.first.title, 'Updated Title');
        expect(rows.first.author, 'Updated Author');
        expect(rows.first.coverPath, 'new_cover.jpg');
        expect(rows.first.lastReadChapterIndex, 3);
        expect(rows.first.lastReadPageIndex, 42);
      },
    );

    test('skips update when local timestamp is newer than remote', () async {
      final localUpdatedAt = DateTime(2024, 6, 17).toUtc();
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Local Title',
              author: 'Local Author',
              filePath: '/path/book.epub',
              format: 'epub',
              updatedAt: Value(localUpdatedAt),
            ),
          );

      final remoteBook = {
        'id': 'book-1',
        'title': 'Older Remote Title',
        'author': 'Remote Author',
        'file_path': '/path/book.epub',
        'cover_path': null,
        'format': 'epub',
        'added_at': DateTime(2024, 6, 14).toUtc().toIso8601String(),
        'last_read_chapter_index': 0,
        'last_read_page_index': 0,
        'is_deleted': false,
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(), // older
      };

      await repo.mergeRemoteBooks([remoteBook]);

      final rows = await db.select(db.books).get();
      expect(rows.length, 1);
      expect(rows.first.title, 'Local Title');
      expect(rows.first.author, 'Local Author');
    });

    test('remote wins when local updatedAt is null', () async {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Local Title',
              author: 'Local Author',
              filePath: '/path/book.epub',
              format: 'epub',
              // updatedAt is null by default
            ),
          );

      final remoteBook = {
        'id': 'book-1',
        'title': 'Remote Wins',
        'author': 'Remote Author',
        'file_path': '/path/book.epub',
        'cover_path': null,
        'format': 'epub',
        'added_at': DateTime(2024, 6, 14).toUtc().toIso8601String(),
        'last_read_chapter_index': 0,
        'last_read_page_index': 0,
        'is_deleted': false,
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
      };

      await repo.mergeRemoteBooks([remoteBook]);

      final rows = await db.select(db.books).get();
      expect(rows.length, 1);
      expect(rows.first.title, 'Remote Wins');
    });

    test('handles deleted book tombstone from remote', () async {
      final remoteBook = {
        'id': 'deleted-book',
        'title': 'Deleted Book',
        'author': 'Author',
        'file_path': '/path/deleted.epub',
        'cover_path': null,
        'format': 'epub',
        'added_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'last_read_chapter_index': 0,
        'last_read_page_index': 0,
        'is_deleted': true,
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
      };

      await repo.mergeRemoteBooks([remoteBook]);

      final rows = await db.select(db.books).get();
      expect(rows.length, 1);
      expect(rows.first.isDeleted, true);
    });

    test('merges multiple remote books in batch', () async {
      final remoteBooks = [
        {
          'id': 'book-a',
          'title': 'Book A',
          'author': 'Author A',
          'file_path': '/path/a.epub',
          'cover_path': null,
          'format': 'epub',
          'added_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'last_read_chapter_index': 0,
          'last_read_page_index': 0,
          'is_deleted': false,
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
        },
        {
          'id': 'book-b',
          'title': 'Book B',
          'author': 'Author B',
          'file_path': '/path/b.pdf',
          'cover_path': null,
          'format': 'pdf',
          'added_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'last_read_chapter_index': 0,
          'last_read_page_index': 0,
          'is_deleted': false,
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
        },
      ];

      await repo.mergeRemoteBooks(remoteBooks);

      final rows = await db.select(db.books).get();
      expect(rows.length, 2);
    });
  });

  // ===========================================================================
  // mergeRemoteHighlights (LWW conflict resolution)
  // ===========================================================================

  group('mergeRemoteHighlights', () {
    setUp(() async {
      // Seed a parent book for FK constraints
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );
    });

    test(
      'inserts new highlight from remote data when local does not exist',
      () async {
        final remoteHighlight = {
          'book_id': 'book-1',
          'chapter_index': 0,
          'start_offset': 10,
          'end_offset': 25,
          'selected_text': 'remote text',
          'highlight_color': 'blue',
          'note': null,
          'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
          'is_deleted': false,
        };

        await repo.mergeRemoteHighlights([remoteHighlight]);

        final rows = await db.select(db.highlights).get();
        expect(rows.length, 1);
        expect(rows.first.selectedText, 'remote text');
        expect(rows.first.bookId, 'book-1');
        expect(rows.first.chapterIndex, 0);
        expect(rows.first.startOffset, 10);
        expect(rows.first.endOffset, 25);
        expect(rows.first.highlightColor, 'blue');
      },
    );

    test('updates existing highlight when remote timestamp is newer', () async {
      await db
          .into(db.highlights)
          .insert(
            HighlightsCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 0,
              startOffset: 10,
              endOffset: 20,
              selectedText: 'original text',
              highlightColor: 'yellow',
              updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
            ),
          );

      final remoteHighlight = {
        'book_id': 'book-1',
        'chapter_index': 0,
        'start_offset': 10,
        'end_offset': 30,
        'selected_text': 'updated text',
        'highlight_color': 'green',
        'note': 'added note',
        'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(), // newer
        'is_deleted': false,
      };

      await repo.mergeRemoteHighlights([remoteHighlight]);

      final rows = await db.select(db.highlights).get();
      expect(rows.length, 1);
      expect(rows.first.selectedText, 'updated text');
      expect(rows.first.highlightColor, 'green');
      expect(rows.first.endOffset, 30);
      expect(rows.first.note, 'added note');
    });

    test('skips update when local highlight is newer than remote', () async {
      await db
          .into(db.highlights)
          .insert(
            HighlightsCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 0,
              startOffset: 10,
              endOffset: 20,
              selectedText: 'local text',
              highlightColor: 'yellow',
              updatedAt: Value(DateTime(2024, 6, 17).toUtc()), // newer
            ),
          );

      final remoteHighlight = {
        'book_id': 'book-1',
        'chapter_index': 0,
        'start_offset': 10,
        'end_offset': 99,
        'selected_text': 'older remote',
        'highlight_color': 'blue',
        'note': null,
        'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(), // older
        'is_deleted': false,
      };

      await repo.mergeRemoteHighlights([remoteHighlight]);

      final rows = await db.select(db.highlights).get();
      expect(rows.length, 1);
      expect(rows.first.selectedText, 'local text');
      expect(rows.first.highlightColor, 'yellow');
      expect(rows.first.endOffset, 20);
    });

    test(
      'highlights are matched by bookId + chapterIndex + startOffset',
      () async {
        // Insert two highlights in the same book with different offsets
        await db
            .into(db.highlights)
            .insert(
              HighlightsCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                startOffset: 10,
                endOffset: 20,
                selectedText: 'first',
                highlightColor: 'yellow',
                updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
              ),
            );
        await db
            .into(db.highlights)
            .insert(
              HighlightsCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                startOffset: 30,
                endOffset: 40,
                selectedText: 'second',
                highlightColor: 'yellow',
                updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
              ),
            );

        // Update only the first highlight
        final remoteHighlight = {
          'book_id': 'book-1',
          'chapter_index': 0,
          'start_offset': 10,
          'end_offset': 25,
          'selected_text': 'first updated',
          'highlight_color': 'green',
          'note': null,
          'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
          'is_deleted': false,
        };

        await repo.mergeRemoteHighlights([remoteHighlight]);

        final rows = await db.select(db.highlights).get();
        expect(rows.length, 2);
        final firstHighlight = rows.firstWhere((h) => h.startOffset == 10);
        expect(firstHighlight.selectedText, 'first updated');
        final secondHighlight = rows.firstWhere((h) => h.startOffset == 30);
        expect(secondHighlight.selectedText, 'second');
      },
    );
  });

  // ===========================================================================
  // mergeRemoteBookmarks (LWW conflict resolution)
  // ===========================================================================

  group('mergeRemoteBookmarks', () {
    setUp(() async {
      await db
          .into(db.books)
          .insert(
            BooksCompanion.insert(
              id: 'book-1',
              title: 'Test Book',
              author: 'Test Author',
              filePath: '/path/book.epub',
              format: 'epub',
            ),
          );
    });

    test(
      'inserts new bookmark from remote data when local does not exist',
      () async {
        final remoteBookmark = {
          'book_id': 'book-1',
          'chapter_index': 1,
          'page_index': 10,
          'label': 'Remote Bookmark',
          'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
          'is_deleted': false,
        };

        await repo.mergeRemoteBookmarks([remoteBookmark]);

        final rows = await db.select(db.bookmarks).get();
        expect(rows.length, 1);
        expect(rows.first.label, 'Remote Bookmark');
        expect(rows.first.bookId, 'book-1');
        expect(rows.first.chapterIndex, 1);
        expect(rows.first.pageIndex, 10);
      },
    );

    test('updates existing bookmark when remote timestamp is newer', () async {
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 1,
              pageIndex: 10,
              label: 'Old Label',
              updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
            ),
          );

      final remoteBookmark = {
        'book_id': 'book-1',
        'chapter_index': 1,
        'page_index': 10,
        'label': 'Updated Label',
        'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(), // newer
        'is_deleted': false,
      };

      await repo.mergeRemoteBookmarks([remoteBookmark]);

      final rows = await db.select(db.bookmarks).get();
      expect(rows.length, 1);
      expect(rows.first.label, 'Updated Label');
    });

    test('skips update when local bookmark is newer than remote', () async {
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 1,
              pageIndex: 10,
              label: 'Local Label',
              updatedAt: Value(DateTime(2024, 6, 17).toUtc()), // newer
            ),
          );

      final remoteBookmark = {
        'book_id': 'book-1',
        'chapter_index': 1,
        'page_index': 10,
        'label': 'Older Remote Label',
        'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(), // older
        'is_deleted': false,
      };

      await repo.mergeRemoteBookmarks([remoteBookmark]);

      final rows = await db.select(db.bookmarks).get();
      expect(rows.length, 1);
      expect(rows.first.label, 'Local Label');
    });

    test('remote wins when local bookmark updatedAt is null', () async {
      await db
          .into(db.bookmarks)
          .insert(
            BookmarksCompanion.insert(
              bookId: 'book-1',
              chapterIndex: 1,
              pageIndex: 10,
              label: 'Local Label',
              // updatedAt is null by default
            ),
          );

      final remoteBookmark = {
        'book_id': 'book-1',
        'chapter_index': 1,
        'page_index': 10,
        'label': 'Remote Wins',
        'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
        'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
        'is_deleted': false,
      };

      await repo.mergeRemoteBookmarks([remoteBookmark]);

      final rows = await db.select(db.bookmarks).get();
      expect(rows.length, 1);
      expect(rows.first.label, 'Remote Wins');
    });

    test(
      'bookmarks are matched by bookId + chapterIndex + pageIndex',
      () async {
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                pageIndex: 5,
                label: 'Page 5',
                updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
              ),
            );
        await db
            .into(db.bookmarks)
            .insert(
              BookmarksCompanion.insert(
                bookId: 'book-1',
                chapterIndex: 0,
                pageIndex: 10,
                label: 'Page 10',
                updatedAt: Value(DateTime(2024, 6, 15).toUtc()),
              ),
            );

        // Update only page 5
        final remoteBookmark = {
          'book_id': 'book-1',
          'chapter_index': 0,
          'page_index': 5,
          'label': 'Updated Page 5',
          'created_at': DateTime(2024, 6, 15).toUtc().toIso8601String(),
          'updated_at': DateTime(2024, 6, 16).toUtc().toIso8601String(),
          'is_deleted': false,
        };

        await repo.mergeRemoteBookmarks([remoteBookmark]);

        final rows = await db.select(db.bookmarks).get();
        expect(rows.length, 2);
        final page5 = rows.firstWhere((b) => b.pageIndex == 5);
        expect(page5.label, 'Updated Page 5');
        final page10 = rows.firstWhere((b) => b.pageIndex == 10);
        expect(page10.label, 'Page 10');
      },
    );
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('merging empty lists does nothing', () async {
      await repo.mergeRemoteBooks([]);
      await repo.mergeRemoteHighlights([]);
      await repo.mergeRemoteBookmarks([]);

      // No errors should occur
      expect(await db.select(db.books).get(), isEmpty);
      expect(await db.select(db.highlights).get(), isEmpty);
      expect(await db.select(db.bookmarks).get(), isEmpty);
    });

    test('getLocalDeltas returns empty for brand new database', () async {
      final now = DateTime.now().toUtc();

      expect(await repo.getLocalBooksDelta(now), isEmpty);
      expect(await repo.getLocalHighlightsDelta(now), isEmpty);
      expect(await repo.getLocalBookmarksDelta(now), isEmpty);
    });
  });
}
