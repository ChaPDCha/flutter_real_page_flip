import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart';

class TxtService {
  /// Matches chapter headings: English "Chapter N",
  /// Korean "제 N장/화" (N required), or Markdown "# heading".
  static final RegExp _chapterRegex = RegExp(
    r'^\s*(?:Chapter\s+\d+|제\s+\d+\s*[장화]|#+\s+.+)',
    caseSensitive: false,
    multiLine: true,
  );

  /// Reads a text file with encoding detection (UTF-8 BOM, else try UTF-8
  /// first, fall back to system default encoding).
  static Future<String> readFile(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    // Detect UTF-8 BOM (EF BB BF)
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3));
    }

    // Try UTF-8 first — most Korean TXT files are UTF-8 encoded
    try {
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('TXT file UTF-8 decode failed, falling back to latin1: $e');
      // latin1 never throws: every byte 0x00-0xFF maps to U+0000-U+00FF
      return latin1.decode(bytes);
    }
  }

  /// Loads a TXT file and parses it into virtual chapters.
  Future<List<EpubChapter>> parseChapters(String filePath) async {
    final content = await readFile(filePath);

    if (content.trim().isEmpty) {
      return [
        EpubChapter()
          ..Title = '빈 책'
          ..HtmlContent = '<html><body><p>내용이 없는 책입니다.</p></body></html>',
      ];
    }

    final matches = _chapterRegex.allMatches(content).toList();
    final chapters = <EpubChapter>[];

    if (matches.isEmpty) {
      // If no chapter markers are found, split large files into virtual 15,000 char chapters
      const maxChapterLength = 15000;
      if (content.length > maxChapterLength) {
        int index = 1;
        for (int i = 0; i < content.length; i += maxChapterLength) {
          final end = (i + maxChapterLength < content.length)
              ? i + maxChapterLength
              : content.length;
          final chunk = content.substring(i, end);
          chapters.add(
            EpubChapter()
              ..Title = '파트 $index'
              ..HtmlContent = _convertToHtml(chunk),
          );
          index++;
        }
      } else {
        chapters.add(
          EpubChapter()
            ..Title = '본문'
            ..HtmlContent = _convertToHtml(content),
        );
      }
    } else {
      // 1. Check if there is prologue text before the first chapter marker
      if (matches.first.start > 0) {
        final prologueText = content.substring(0, matches.first.start).trim();
        if (prologueText.isNotEmpty) {
          chapters.add(
            EpubChapter()
              ..Title = '프롤로그'
              ..HtmlContent = _convertToHtml(prologueText),
          );
        }
      }

      // 2. Add each chapter
      for (int i = 0; i < matches.length; i++) {
        final currentMatch = matches[i];
        final start = currentMatch.start;
        final end = (i < matches.length - 1)
            ? matches[i + 1].start
            : content.length;

        final fullMatchText = content.substring(start, end).trim();

        // Find the end of the matched title line
        final firstNewline = fullMatchText.indexOf('\n');
        String title = '';
        String body = '';

        if (firstNewline != -1) {
          title = fullMatchText.substring(0, firstNewline).trim();
          body = fullMatchText.substring(firstNewline).trim();
        } else {
          title = fullMatchText;
          body = '';
        }

        if (title.isEmpty) {
          title = '제 ${i + 1}장';
        }

        chapters.add(
          EpubChapter()
            ..Title = title
            ..HtmlContent = _convertToHtml(body),
        );
      }
    }

    return chapters;
  }

  String _convertToHtml(String text) {
    final paragraphs = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '<p>$line</p>')
        .join('\n');
    return '<html><body>$paragraphs</body></html>';
  }
}
