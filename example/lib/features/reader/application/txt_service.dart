import 'dart:io';
import 'package:epubx/epubx.dart';

class TxtService {
  static final RegExp _chapterRegex = RegExp(
    r'^\s*(Chapter\s+\d+|제\s*\d+\s*[장화]|#+\s+.+)',
    caseSensitive: false,
    multiLine: true,
  );

  /// Loads a TXT file and parses it into virtual chapters.
  Future<List<EpubChapter>> parseChapters(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();

    if (content.trim().isEmpty) {
      return [
        EpubChapter()
          ..Title = '빈 책'
          ..HtmlContent = '<html><body><p>내용이 없는 책입니다.</p></body></html>'
      ];
    }

    final matches = _chapterRegex.allMatches(content).toList();
    final chapters = <EpubChapter>[];

    if (matches.isEmpty) {
      // If no chapter markers are found, split large files into virtual 15,000 char chapters to prevent lag
      const maxChapterLength = 15000;
      if (content.length > maxChapterLength) {
        int index = 1;
        for (int i = 0; i < content.length; i += maxChapterLength) {
          final end = (i + maxChapterLength < content.length) ? i + maxChapterLength : content.length;
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
      // Split using matches
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
        final end = (i < matches.length - 1) ? matches[i + 1].start : content.length;
        
        // Extract chapter title (the matched line)
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
