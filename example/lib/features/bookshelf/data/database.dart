import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

@DataClassName('BookDb')
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get filePath => text().unique()();
  TextColumn get coverPath => text().nullable()();
  TextColumn get format => text()();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get lastReadChapterIndex =>
      integer().withDefault(const Constant(0))();
  IntColumn get lastReadPageIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Highlights extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  IntColumn get startOffset => integer()();
  IntColumn get endOffset => integer()();
  TextColumn get selectedText => text()();
  TextColumn get highlightColor => text()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class Bookmarks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  IntColumn get pageIndex => integer()();
  TextColumn get label => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
}

class ReadingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId =>
      text().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()();
  IntColumn get durationSeconds => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Books, Highlights, Bookmarks, ReadingLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS book_contents_fts USING fts5(bookId, chapterIndex, content, tokenize="unicode61");',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(books, books.updatedAt);
        await m.addColumn(books, books.isDeleted);
        await m.addColumn(bookmarks, bookmarks.updatedAt);

        // Populate default time vectors and tombstones for legacy records to prevent Null mapping errors
        await customStatement(
          "UPDATE books SET updated_at = CAST(strftime('%s', 'now') AS INTEGER), is_deleted = 0;",
        );
        await customStatement(
          "UPDATE bookmarks SET updated_at = CAST(strftime('%s', 'now') AS INTEGER);",
        );
      }
      await customStatement(
        'CREATE VIRTUAL TABLE IF NOT EXISTS book_contents_fts USING fts5(bookId, chapterIndex, content, tokenize="unicode61");',
      );
    },
  );

  // Highlights DB Helpers
  Future<List<Highlight>> getHighlightsForBook(String bookId) {
    return (select(highlights)..where(
          (tbl) => tbl.bookId.equals(bookId) & tbl.isDeleted.equals(false),
        ))
        .get();
  }

  Future<int> insertHighlight(HighlightsCompanion companion) {
    return into(highlights).insert(companion);
  }

  Future<void> deleteHighlight(int id) {
    return (update(highlights)..where((tbl) => tbl.id.equals(id))).write(
      HighlightsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // Bookmarks DB Helpers
  Future<List<Bookmark>> getBookmarksForBook(String bookId) {
    return (select(bookmarks)..where(
          (tbl) => tbl.bookId.equals(bookId) & tbl.isDeleted.equals(false),
        ))
        .get();
  }

  Future<int> insertBookmark(BookmarksCompanion companion) {
    return into(bookmarks).insert(companion);
  }

  Future<void> deleteBookmark(int id) {
    return (update(bookmarks)..where((tbl) => tbl.id.equals(id))).write(
      const BookmarksCompanion(isDeleted: Value(true)),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'realbook.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
