import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:epubx/epubx.dart';
import 'package:html/dom.dart' show Element, Node, Text;
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

    // Select common block-level tags plus HTML5 semantic elements to preserve structure
    final blocks =
        document.body?.querySelectorAll(
          'p, div, h1, h2, h3, h4, h5, h6, li, tr, '
          'section, article, header, main, figure, figcaption, blockquote, td',
        ) ??
        [];

    if (blocks.isEmpty) {
      // Fallback to simple text extraction if no standard blocks are found
      final text =
          document.body?.text.trim() ??
          document.documentElement?.text.trim() ??
          '';
      _chapterTextCache[chapter] = text;
      return text;
    }

    final buffer = StringBuffer();
    for (final block in blocks) {
      final text = block.text.trim();
      if (text.isEmpty) {
        continue;
      }

      // Skip wrapper blocks when a descendant block already carries the same text.
      if (_hasDescendantTextBlock(block)) {
        // Extract direct text nodes (not inside child blocks) to avoid
        // losing text that lives alongside block children (e.g. EPUB3
        // with mixed content in wrapper elements).
        final directText = _getDirectText(block);
        if (directText.isNotEmpty) {
          buffer.writeln(directText);
          buffer.writeln();
        }
        continue;
      }

      buffer.writeln(text);
      if (block.localName == 'p' || block.localName?.startsWith('h') == true) {
        buffer.writeln();
      } else {
        buffer.writeln();
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

  /// True when a nested block-level element already contributes non-empty text.
  bool _hasDescendantTextBlock(Element block) {
    // Must match the block-level selector used in getChapterText
    const blockTags = {
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'li',
      'tr',
      'section',
      'article',
      'header',
      'main',
      'figure',
      'figcaption',
      'blockquote',
      'td',
    };
    for (final descendant in block.querySelectorAll(blockTags.join(', '))) {
      if (identical(descendant, block)) {
        continue;
      }
      if (descendant.text.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Extracts only the direct text content of [element], excluding text
  /// inside child block-level elements. This preserves text that lives
  /// alongside block children in wrapper elements.
  String _getDirectText(Element element) {
    final buffer = StringBuffer();
    for (final node in element.nodes) {
      if (node.nodeType == Node.TEXT_NODE) {
        final text = (node as Text).text.trim();
        if (text.isNotEmpty) {
          buffer.write('$text ');
        }
      }
    }
    return buffer.toString().trim();
  }

  void _addChapterToList(EpubChapter chapter, List<EpubChapter> list) {
    list.add(chapter);
    for (final subChapter in chapter.SubChapters ?? <EpubChapter>[]) {
      _addChapterToList(subChapter, list);
    }
  }
}
