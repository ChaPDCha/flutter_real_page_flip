import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;

void main() {
  late File tempDbFile;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('realbook_migration_test');
    tempDbFile = File(p.join(tempDir.path, 'migration_test.db'));
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
    'Drift Schema V1 to V2 Migration preserves data and adds sync columns',
    () async {
      // 1. Create a raw SQLite file replicating Schema Version 1
      final rawDb = sqlite3.open(tempDbFile.path);

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
      final db = AppDatabase(NativeDatabase(tempDbFile));

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

      await db.close();
    },
  );
}
