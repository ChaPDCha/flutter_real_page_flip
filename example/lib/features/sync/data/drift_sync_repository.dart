import 'package:drift/drift.dart';
import '../../bookshelf/data/database.dart';
import '../domain/sync_repository.dart';

class DriftSyncRepository implements SyncRepository {
  final AppDatabase _db;

  DriftSyncRepository(this._db);

  @override
  Future<List<Map<String, dynamic>>> getLocalBooksDelta(DateTime since) async {
    final query = _db.select(_db.books)
      ..where((tbl) => tbl.updatedAt.isBiggerThan(Constant(since)));
    final rows = await query.get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'title': row.title,
            'author': row.author,
            'file_path': row.filePath,
            'cover_path': row.coverPath,
            'format': row.format,
            'added_at': row.addedAt.toUtc().toIso8601String(),
            'last_read_chapter_index': row.lastReadChapterIndex,
            'last_read_page_index': row.lastReadPageIndex,
            'is_deleted': row.isDeleted,
            'updated_at':
                row.updatedAt?.toUtc().toIso8601String() ??
                DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalHighlightsDelta(
    DateTime since,
  ) async {
    final query = _db.select(_db.highlights)
      ..where((tbl) => tbl.updatedAt.isBiggerThan(Constant(since)));
    final rows = await query.get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'book_id': row.bookId,
            'chapter_index': row.chapterIndex,
            'start_offset': row.startOffset,
            'end_offset': row.endOffset,
            'selected_text': row.selectedText,
            'highlight_color': row.highlightColor,
            'note': row.note,
            'is_deleted': row.isDeleted,
            'created_at': row.createdAt.toUtc().toIso8601String(),
            'updated_at': row.updatedAt.toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLocalBookmarksDelta(
    DateTime since,
  ) async {
    final query = _db.select(_db.bookmarks)
      ..where((tbl) => tbl.updatedAt.isBiggerThan(Constant(since)));
    final rows = await query.get();
    return rows
        .map(
          (row) => {
            'id': row.id,
            'book_id': row.bookId,
            'chapter_index': row.chapterIndex,
            'page_index': row.pageIndex,
            'label': row.label,
            'is_deleted': row.isDeleted,
            'created_at': row.createdAt.toUtc().toIso8601String(),
            'updated_at':
                row.updatedAt?.toUtc().toIso8601String() ??
                DateTime.now().toUtc().toIso8601String(),
          },
        )
        .toList();
  }

  @override
  Future<void> mergeRemoteBooks(List<Map<String, dynamic>> remoteBooks) async {
    if (remoteBooks.isEmpty) return;

    // Batch-fetch existing local rows by ID to avoid N+1 SELECTs
    final ids = remoteBooks.map((r) => r['id'] as String).toList();
    final localRows = await (_db.select(_db.books)
      ..where((tbl) => tbl.id.isIn(ids))).get();
    final localMap = {for (final row in localRows) row.id: row};

    await _db.transaction(() async {
      for (final raw in remoteBooks) {
        final id = raw['id'] as String;
        final remoteUpdatedAt = DateTime.parse(raw['updated_at'] as String);
        final local = localMap[id];

        if (local == null) {
          await _db
              .into(_db.books)
              .insertOnConflictUpdate(
                BooksCompanion.insert(
                  id: id,
                  title: raw['title'] as String,
                  author: raw['author'] as String,
                  filePath: raw['file_path'] as String,
                  coverPath: Value(raw['cover_path'] as String?),
                  format: raw['format'] as String,
                  addedAt: Value(DateTime.parse(raw['added_at'] as String)),
                  lastReadChapterIndex: Value(
                    raw['last_read_chapter_index'] as int,
                  ),
                  lastReadPageIndex: Value(raw['last_read_page_index'] as int),
                  updatedAt: Value(remoteUpdatedAt),
                  isDeleted: Value(raw['is_deleted'] as bool),
                ),
              );
        } else {
          if (local.updatedAt == null ||
              remoteUpdatedAt.isAfter(local.updatedAt!)) {
            await (_db.update(
              _db.books,
            )..where((tbl) => tbl.id.equals(id))).write(
              BooksCompanion(
                title: Value(raw['title'] as String),
                author: Value(raw['author'] as String),
                coverPath: Value(raw['cover_path'] as String?),
                lastReadChapterIndex: Value(
                  raw['last_read_chapter_index'] as int,
                ),
                lastReadPageIndex: Value(raw['last_read_page_index'] as int),
                updatedAt: Value(remoteUpdatedAt),
                isDeleted: Value(raw['is_deleted'] as bool),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Future<void> mergeRemoteHighlights(
    List<Map<String, dynamic>> remoteHighlights,
  ) async {
    if (remoteHighlights.isEmpty) return;

    // Batch-fetch existing rows by natural key to avoid N+1
    final bookIds = remoteHighlights.map((r) => r['book_id'] as String).toList();
    final chapterIndices = remoteHighlights.map((r) => r['chapter_index'] as int).toList();
    final startOffsets = remoteHighlights.map((r) => r['start_offset'] as int).toList();

    final localRows = await (_db.select(_db.highlights)
      ..where(
        (tbl) =>
            tbl.bookId.isIn(bookIds) &
            tbl.chapterIndex.isIn(chapterIndices) &
            tbl.startOffset.isIn(startOffsets),
      )).get();

    // Build lookup key: "bookId:chapterIndex:startOffset"
    final localMap = {
      for (final row in localRows)
        '${row.bookId}:${row.chapterIndex}:${row.startOffset}': row,
    };

    await _db.transaction(() async {
      for (final raw in remoteHighlights) {
        final bookId = raw['book_id'] as String;
        final chapterIndex = raw['chapter_index'] as int;
        final startOffset = raw['start_offset'] as int;
        final remoteUpdatedAt = DateTime.parse(raw['updated_at'] as String);
        final key = '$bookId:$chapterIndex:$startOffset';
        final local = localMap[key];

        if (local == null) {
          await _db
              .into(_db.highlights)
              .insert(
                HighlightsCompanion.insert(
                  bookId: bookId,
                  chapterIndex: chapterIndex,
                  startOffset: startOffset,
                  endOffset: raw['end_offset'] as int,
                  selectedText: raw['selected_text'] as String,
                  highlightColor: raw['highlight_color'] as String,
                  note: Value(raw['note'] as String?),
                  createdAt: Value(DateTime.parse(raw['created_at'] as String)),
                  updatedAt: Value(remoteUpdatedAt),
                  isDeleted: Value(raw['is_deleted'] as bool),
                ),
              );
        } else {
          if (remoteUpdatedAt.isAfter(local.updatedAt)) {
            await (_db.update(
              _db.highlights,
            )..where((tbl) => tbl.id.equals(local.id))).write(
              HighlightsCompanion(
                endOffset: Value(raw['end_offset'] as int),
                selectedText: Value(raw['selected_text'] as String),
                highlightColor: Value(raw['highlight_color'] as String),
                note: Value(raw['note'] as String?),
                updatedAt: Value(remoteUpdatedAt),
                isDeleted: Value(raw['is_deleted'] as bool),
              ),
            );
          }
        }
      }
    });
  }

  @override
  Future<void> mergeRemoteBookmarks(
    List<Map<String, dynamic>> remoteBookmarks,
  ) async {
    if (remoteBookmarks.isEmpty) return;

    final bookIds = remoteBookmarks.map((r) => r['book_id'] as String).toList();
    final chapterIndices = remoteBookmarks.map((r) => r['chapter_index'] as int).toList();
    final pageIndices = remoteBookmarks.map((r) => r['page_index'] as int).toList();

    final localRows = await (_db.select(_db.bookmarks)
      ..where(
        (tbl) =>
            tbl.bookId.isIn(bookIds) &
            tbl.chapterIndex.isIn(chapterIndices) &
            tbl.pageIndex.isIn(pageIndices),
      )).get();

    final localMap = {
      for (final row in localRows)
        '${row.bookId}:${row.chapterIndex}:${row.pageIndex}': row,
    };

    await _db.transaction(() async {
      for (final raw in remoteBookmarks) {
        final bookId = raw['book_id'] as String;
        final chapterIndex = raw['chapter_index'] as int;
        final pageIndex = raw['page_index'] as int;
        final remoteUpdatedAt = DateTime.parse(raw['updated_at'] as String);
        final key = '$bookId:$chapterIndex:$pageIndex';
        final local = localMap[key];

        if (local == null) {
          await _db
              .into(_db.bookmarks)
              .insert(
                BookmarksCompanion.insert(
                  bookId: bookId,
                  chapterIndex: chapterIndex,
                  pageIndex: pageIndex,
                  label: raw['label'] as String,
                  createdAt: Value(DateTime.parse(raw['created_at'] as String)),
                  updatedAt: Value(remoteUpdatedAt),
                  isDeleted: Value(raw['is_deleted'] as bool),
                ),
              );
        } else {
          if (local.updatedAt == null ||
              remoteUpdatedAt.isAfter(local.updatedAt!)) {
            await (_db.update(
              _db.bookmarks,
            )..where((tbl) => tbl.id.equals(local.id))).write(
              BookmarksCompanion(
                label: Value(raw['label'] as String),
                updatedAt: Value(remoteUpdatedAt),
                isDeleted: Value(raw['is_deleted'] as bool),
              ),
            );
          }
        }
      }
    });
  }
}
