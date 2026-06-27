import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('realbook_migration_test');
  });

  tearDown(() async {
    try {
      if (tempDir.existsSync()) {
        // Yield time for SQLite native handles to fully dispose
        await Future.delayed(const Duration(milliseconds: 150));
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {
      // Gracefully bypass system locks in test context
    }
  });

  test(
    'Fresh database onCreate creates all tables and FTS5 index',
    () async {
      final dbFile = File(p.join(tempDir.path, 'fresh.db'));
      final db = AppDatabase(NativeDatabase(dbFile));

      // Verify all 4 business tables exist via SELECT
      final booksList = await db.select(db.books).get();
      expect(booksList, isEmpty);

      final highlightsList = await db.select(db.highlights).get();
      expect(highlightsList, isEmpty);

      final bookmarksList = await db.select(db.bookmarks).get();
      expect(bookmarksList, isEmpty);

      final readingLogsList = await db.select(db.readingLogs).get();
      expect(readingLogsList, isEmpty);

      // Verify FTS5 virtual table exists and accepts inserts
      await db.customStatement(
        'INSERT INTO book_contents_fts (bookId, chapterIndex, content) VALUES (?, ?, ?)',
        ['book-1', 0, 'fresh db test content'],
      );
      final rows = await db.customSelect(
        'SELECT content FROM book_contents_fts WHERE book_contents_fts MATCH ?',
        variables: [Variable.withString('fresh')],
      ).get();
      expect(rows.length, 1);

      await db.close();
    },
  );

  test(
    'Drift Schema V1 to V2 Migration preserves data and adds sync columns',
    () async {
      // 1. Create a raw SQLite file replicating Schema Version 1
      final dbFile = File(p.join(tempDir.path, 'migration_test.db'));
      final rawDb = sqlite3.open(dbFile.path);

      // Explicitly set SQLite user_version to 1 so Drift triggers onUpgrade
      rawDb.execute('PRAGMA user_version = 1;');

      rawDb.execute('''
      CREATE TABLE books (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        file_path TEXT NOT NULL UNIQUE,
        cover_path TEXT,
        format TEXT NOT NULL,
        added_at INTEGER NOT NULL,
        last_read_chapter_index INTEGER NOT NULL DEFAULT 0,
        last_read_page_index INTEGER NOT NULL DEFAULT 0
      );
    ''');

      rawDb.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        page_index INTEGER NOT NULL,
        label TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      );
    ''');

      rawDb.execute('''
      CREATE TABLE highlights (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        start_offset INTEGER NOT NULL,
        end_offset INTEGER NOT NULL,
        selected_text TEXT NOT NULL,
        highlight_color TEXT NOT NULL,
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      );
    ''');

      rawDb.execute('''
      CREATE TABLE reading_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL,
        chapter_index INTEGER NOT NULL,
        duration_seconds INTEGER NOT NULL,
        timestamp INTEGER NOT NULL
      );
    ''');

      // Seed test data in raw Schema Version 1
      rawDb.execute('''
      INSERT INTO books (id, title, author, file_path, format, added_at)
      VALUES ('book-1', 'Legacy Book', 'Legacy Author', 'path/to/legacy.epub', 'epub', 1700000000);
    ''');

      rawDb.execute('''
      INSERT INTO bookmarks (book_id, chapter_index, page_index, label, created_at, is_deleted)
      VALUES ('book-1', 1, 2, 'Legacy Bookmark', 1700000100, 0);
    ''');

      rawDb.dispose(); // Gracefully release raw lock

      // 2. Open database via Drift AppDatabase configured with Schema Version 2
      final db = AppDatabase(NativeDatabase(dbFile));

      // Fetch records to trigger automatic onUpgrade migrations
      final booksList = await db.select(db.books).get();
      expect(booksList.length, 1);
      expect(booksList.first.title, 'Legacy Book');
      expect(booksList.first.id, 'book-1');

      // Verify V2 fields are added and initialized with defaults
      expect(booksList.first.isDeleted, false);
      expect(booksList.first.updatedAt, isNotNull);

      final bookmarksList = await db.select(db.bookmarks).get();
      expect(bookmarksList.length, 1);
      expect(bookmarksList.first.label, 'Legacy Bookmark');
      expect(bookmarksList.first.updatedAt, isNotNull);

      // Verify FTS5 virtual table exists after migration
      await db.customStatement(
        'INSERT INTO book_contents_fts (bookId, chapterIndex, content) VALUES (?, ?, ?)',
        ['book-1', 0, 'fts5 migrated content'],
      );
      final ftsRows = await db.customSelect(
        'SELECT content FROM book_contents_fts WHERE book_contents_fts MATCH ?',
        variables: [Variable.withString('migrated')],
      ).get();
      expect(ftsRows.length, 1);

      await db.close();
    },
  );
}
