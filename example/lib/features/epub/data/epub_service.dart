import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' show parse;

class EpubService {
  final Expando<String> _chapterTextCache = Expando<String>();

  Future<EpubBook> loadBook(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return compute(EpubReader.readBook, bytes);
  }

  /// Extracts clean plain text with preserved paragraph breaks from an EPUB chapter.
  String getChapterText(EpubChapter chapter) {
    final cachedText = _chapterTextCache[chapter];
    if (cachedText != null) {
      return cachedText;
    }

    final htmlContent = chapter.HtmlContent;
    if (htmlContent == null || htmlContent.trim().isEmpty) {
      return '';
    }

    final document = parse(htmlContent);
    
    // Remove unwanted tags
    document.querySelectorAll('script').forEach((e) => e.remove());
    document.querySelectorAll('style').forEach((e) => e.remove());
    document.querySelectorAll('head').forEach((e) => e.remove());

    // Select common block-level tags to preserve structure
    final blocks = document.body?.querySelectorAll('p, div, h1, h2, h3, h4, h5, h6, li, tr') ?? [];
    
    if (blocks.isEmpty) {
      // Fallback to simple text extraction if no standard blocks are found
      final text = document.body?.text.trim() ?? document.documentElement?.text.trim() ?? '';
      _chapterTextCache[chapter] = text;
      return text;
    }

    final buffer = StringBuffer();
    for (final block in blocks) {
      final text = block.text.trim();
      if (text.isNotEmpty) {
        // Skip child text of other parsed block-level elements to prevent duplicates
        // (e.g. div containing a p, we only want the text once)
        if (block.localName == 'div' && block.querySelector('p, div') != null) {
          continue; 
        }
        
        // Add double spacing for paragraphs, single for list items or table rows
        buffer.writeln(text);
        if (block.localName == 'p' || block.localName?.startsWith('h') == true) {
          buffer.writeln(); 
        } else {
          buffer.writeln();
        }
      }
    }
    final text = buffer.toString().trim();
    _chapterTextCache[chapter] = text;
    return text;
  }

  /// Flattens all chapters (including sub-chapters) in the book into a single list.
  List<EpubChapter> flattenChapters(EpubBook book) {
    final list = <EpubChapter>[];
    for (final chapter in book.Chapters ?? <EpubChapter>[]) {
      _addChapterToList(chapter, list);
    }
    return list;
  }

  void _addChapterToList(EpubChapter chapter, List<EpubChapter> list) {
    list.add(chapter);
    for (final subChapter in chapter.SubChapters ?? <EpubChapter>[]) {
      _addChapterToList(subChapter, list);
    }
  }
}
