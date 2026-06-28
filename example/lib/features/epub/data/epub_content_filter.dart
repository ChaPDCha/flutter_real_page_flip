import 'package:html/dom.dart' show Document, Element;

/// Filters non-content elements from EPUB HTML documents.
///
/// Handles EPUB3 semantic markup (`epub:type` vocabulary), common publisher
/// CSS class/id patterns (Apple Books, Kindle, Kobo, calibre), and heuristic
/// page-number detection. Matches the filtering quality of major reading
/// systems (iBooks, Kindle, Kobo).
class EpubContentFilter {
  /// EPUB3 [epub:type] values that represent non-content or navigation-only
  /// elements. These are excluded from the extracted reading text.
  ///
  /// See: https://www.w3.org/TR/epub-ssv/
  static const Set<String> nonContentTypes = {
    // Page navigation
    'pagebreak',
    'page-number',
    'page_list',
    'pagenum', // Legacy/deprecated
    // Note references and note bodies
    'noteref',
    'footnote',
    'rearnote',
    'endnote',
    'footnotes',
    'endnotes',

    // Front/back matter
    'copyright-page',
    'titlepage',
    'halftitlepage',
    'colophon',
    'imprint',

    // Navigation
    'toc',
    'contents',
    'landmarks',
    'nav',

    // Back-of-book
    'index',
    'bibliography',
  };

  /// CSS classes that indicate non-content elements, drawn from:
  /// - Apple Books/iBooks conventions
  /// - Amazon Kindle/KF8 conventions
  /// - Kobo conventions
  /// - calibre auto-generated EPUB
  /// - Common publisher-specific (Penguin, Hachette, HarperCollins)
  static const Set<String> nonContentClasses = {
    // Page numbers
    'page-number',
    'pagenum',
    'page_num',
    'pg-num',
    'pgnum',
    'pageNum',
    'pageNumber',

    // Footnotes/endnotes
    'footnote',
    'footnotes',
    'endnote',
    'endnotes',
    'noteref',
    'noteRef',

    // Section/copyright
    'copyright',
    'copyright-page',
    'colophon',
    'imprint',

    // Page breaks
    'pagebreak',
    'page-break',
    'kindle-pagebreak',
    'mbppagebreak',
    'pb',

    // TOC/nav
    'toc',
    'contents',
    'nav',

    // Pagination decoration
    'pagination',
    'pagehead',
    'pagefoot',
    'pageFoot',

    // Common publisher patterns
    'calibre_pagenum',
  };

  /// Common ID values for non-content sections.
  static const Set<String> nonContentIds = {
    'page-number',
    'pagenum',
    'pageNum',
    'page_num',
    'footnote',
    'footnotes',
    'endnote',
    'endnotes',
    'copyright',
    'colophon',
    'toc',
    'contents',
    'nav',
  };

  /// Text-only patterns for heuristic page-number detection.
  ///
  /// Only removes elements whose total text length is ≤ 20 chars AND whose
  /// text matches these patterns, to avoid false positives.
  static final RegExp _pageNumberText = RegExp(
    r'^(?:\d+'
    r'|\[\-?\d+\]'
    r'|\(\-?\d+\)'
    r'|[—–—‒–—―]\s*\d+\s*[—–—‒–—―]'
    r'|\d+\s*/\s*\d+' // "42/250"
    r'|pg\.?\s*\d+'
    r'|p\.?\s*\d+'
    r')$',
    caseSensitive: false,
  );

  /// Removes non-content elements from [document] in-place.
  static void removeNonContent(Document document) {
    final elements = document.querySelectorAll('*');
    final toRemove = <Element>[];

    for (final element in elements) {
      if (_shouldRemove(element)) {
        toRemove.add(element);
      }
    }

    for (final element in toRemove) {
      element.remove();
    }
  }

  static bool _shouldRemove(Element element) {
    // 1. Remove <nav> elements (EPUB3 navigation)
    if (element.localName == 'nav') return true;

    // 2. Check epub:type attribute (EPUB3 semantic vocabulary)
    //    May contain multiple space-separated values.
    final epubType = element.attributes['epub:type'];
    if (epubType != null) {
      for (final type in epubType.split(RegExp(r'\s+'))) {
        if (nonContentTypes.contains(type)) return true;
      }
    }

    // 3. Check CSS class attribute against known non-content classes
    final classAttr = element.attributes['class'];
    if (classAttr != null) {
      for (final cls in classAttr.split(RegExp(r'\s+'))) {
        if (nonContentClasses.contains(cls.toLowerCase())) return true;
      }
    }

    // 4. Check id attribute
    final idAttr = element.attributes['id'];
    if (idAttr != null && nonContentIds.contains(idAttr.toLowerCase())) {
      return true;
    }

    // 5. Heuristic: standalone page numbers
    //    Only applies to short leaf elements whose entire text content is
    //    a page-number-like pattern.
    if (element.children.isEmpty && element.text.trim().length <= 20) {
      final text = element.text.trim();
      if (text.isNotEmpty && _pageNumberText.hasMatch(text)) {
        return true;
      }
    }

    return false;
  }
}
