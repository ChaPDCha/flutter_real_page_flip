import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../bookshelf/domain/book.dart';
import '../../bookshelf/data/database.dart';
import '../../epub/data/epub_service.dart';
import 'txt_service.dart';

class SearchResult {
  final int chapterIndex;
  final String snippet;
  final int matchIndex;

  SearchResult({
    required this.chapterIndex,
    required this.snippet,
    required this.matchIndex,
  });
}

class ParsedChapterContent {
  final int chapterIndex;
  final String content;

  ParsedChapterContent(this.chapterIndex, this.content);
}

class SearchService {
  final AppDatabase _db;

  SearchService(this._db);

  /// Indexes the book content asynchronously inside a background Isolate.
  Future<void> indexBook(Book book) async {
    if (book.format == BookFormat.pdf) {
      return; // PDF contains fixed vector layout
    }

    final params = {'filePath': book.filePath, 'format': book.format.name};

    // Run heavy EPUB/TXT content parsing in background isolate to keep 120 FPS
    final parsed = await compute(_parseBookInIsolate, params);
    if (parsed.isEmpty) return;

    // Delete existing indices to prevent duplicates on re-import
    await _db.customStatement(
      'DELETE FROM book_contents_fts WHERE bookId = ?',
      [book.id],
    );

    // Batch insert using custom SQL in a single fast transaction
    await _db.transaction(() async {
      for (final item in parsed) {
        if (item.content.trim().isNotEmpty) {
          await _db.customStatement(
            'INSERT INTO book_contents_fts (bookId, chapterIndex, content) VALUES (?, ?, ?)',
            [book.id, item.chapterIndex, item.content],
          );
        }
      }
    });
  }

  /// Searches for matches inside the FTS5 virtual table.
  /// Uses LIKE query to guarantee 100% accurate substring matching for CJK characters.
  Future<List<SearchResult>> searchBook(String bookId, String query) async {
    if (query.trim().isEmpty) return [];

    final rows = await _db
        .customSelect(
          'SELECT chapterIndex, content FROM book_contents_fts WHERE bookId = ? AND content LIKE ?',
          variables: [
            Variable.withString(bookId),
            Variable.withString('%$query%'),
          ],
        )
        .get();

    final results = <SearchResult>[];
    for (final row in rows) {
      final chapterIndex = row.read<int>('chapterIndex');
      final content = row.read<String>('content');

      int index = content.toLowerCase().indexOf(query.toLowerCase());
      while (index != -1) {
        final start = (index - 25).clamp(0, content.length);
        final end = (index + query.length + 35).clamp(0, content.length);
        final snippet =
            '${start > 0 ? "..." : ""}'
            '${content.substring(start, end).replaceAll('\n', ' ').trim()}'
            '${end < content.length ? "..." : ""}';

        results.add(
          SearchResult(
            chapterIndex: chapterIndex,
            snippet: snippet,
            matchIndex: index,
          ),
        );

        // Find next match in the same chapter
        index = content.toLowerCase().indexOf(query.toLowerCase(), index + 1);
        if (results.length >= 50) {
          break; // Limit to top 50 matches to prevent overflow
        }
      }
      if (results.length >= 50) break;
    }

    return results;
  }
}

/// Parsing function executed completely inside the background Isolate
Future<List<ParsedChapterContent>> _parseBookInIsolate(
  Map<String, dynamic> params,
) async {
  final filePath = params['filePath'] as String;
  final format = params['format'] as String;
  final chaptersText = <ParsedChapterContent>[];

  try {
    if (format == 'txt') {
      final txtService = TxtService();
      final chapters = await txtService.parseChapters(filePath);
      for (int i = 0; i < chapters.length; i++) {
        final html = chapters[i].HtmlContent ?? '';
        final cleanText = html
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        chaptersText.add(ParsedChapterContent(i, cleanText));
      }
    } else if (format == 'epub') {
      final epubService = EpubService();
      final epubBook = await epubService.loadBook(filePath);
      final chapters = epubService.flattenChapters(epubBook);
      for (int i = 0; i < chapters.length; i++) {
        final cleanText = epubService.getChapterText(chapters[i]);
        chaptersText.add(ParsedChapterContent(i, cleanText));
      }
    }
  } catch (_) {}

  return chaptersText;
}
