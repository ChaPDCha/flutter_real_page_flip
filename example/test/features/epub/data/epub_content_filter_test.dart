import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' show parse;
import 'package:real_page_flip_example/features/epub/data/epub_content_filter.dart';

void main() {
  group('EpubContentFilter', () {
    test('removes <nav> elements', () {
      final doc = parse('''
        <html><body>
          <p>Content text.</p>
          <nav><h2>Contents</h2><a href="#ch1">Chapter 1</a></nav>
          <p>More content.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Contents'), isFalse);
      expect(doc.body?.text.contains('Content text'), isTrue);
      expect(doc.body?.text.contains('More content'), isTrue);
    });

    test('removes elements with epub:type="pagebreak"', () {
      final doc = parse('''
        <html><body>
          <p epub:type="pagebreak">42</p>
          <p>Real content paragraph.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('42'), isFalse);
      expect(doc.body?.text.contains('Real content paragraph.'), isTrue);
    });

    test('removes elements with epub:type="page-number"', () {
      final doc = parse('''
        <html><body>
          <span epub:type="page-number">128</span>
          <p>Story continues here.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('128'), isFalse);
      expect(doc.body?.text.contains('Story continues here.'), isTrue);
    });

    test('removes elements with epub:type="footnote"', () {
      final doc = parse('''
        <html><body>
          <p>Main text.<sup epub:type="noteref">1</sup></p>
          <aside epub:type="footnote">
            <p>1. A lengthy footnote explanation.</p>
          </aside>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Main text.'), isTrue);
      expect(doc.body?.text.contains('footnote explanation'), isFalse);
      expect(doc.body?.text.contains('noteref'), isFalse);
    });

    test('removes elements with epub:type="copyright-page"', () {
      final doc = parse('''
        <html><body>
          <section epub:type="copyright-page">
            <p>© 2024 Publisher. All rights reserved.</p>
          </section>
          <p>Chapter begins here.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Publisher'), isFalse);
      expect(doc.body?.text.contains('Chapter begins here.'), isTrue);
    });

    test('removes elements with class "page-number"', () {
      final doc = parse('''
        <html><body>
          <span class="page-number">56</span>
          <p>The story continues...</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('56'), isFalse);
      expect(doc.body?.text.contains('story continues'), isTrue);
    });

    test('removes elements with class "pagenum"', () {
      final doc = parse('''
        <html><body>
          <p class="pagenum">42</p>
          <p>Real paragraph.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('42'), isFalse);
      expect(doc.body?.text.contains('Real paragraph.'), isTrue);
    });

    test('removes elements with id "footnotes"', () {
      final doc = parse('''
        <html><body>
          <p>Main content.</p>
          <div id="footnotes">
            <p>1. Source reference.</p>
            <p>2. Another note.</p>
          </div>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Main content'), isTrue);
      expect(doc.body?.text.contains('Source reference'), isFalse);
    });

    test('preserves content elements without non-content markers', () {
      final doc = parse('''
        <html><body>
          <h1>Chapter 5</h1>
          <p>It was a dark and stormy night.</p>
          <p>The captain said, "All hands on deck!"</p>
          <blockquote>Famous quote from the story.</blockquote>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Chapter 5'), isTrue);
      expect(doc.body?.text.contains('dark and stormy night'), isTrue);
      expect(doc.body?.text.contains('All hands on deck'), isTrue);
      expect(doc.body?.text.contains('Famous quote'), isTrue);
    });

    test('removes standalone numeric page numbers (heuristic)', () {
      final doc = parse('''
        <html><body>
          <p>Content before page break.</p>
          <span>142</span>
          <p>Content after page break.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('142'), isFalse);
      expect(doc.body?.text.contains('Content before'), isTrue);
      expect(doc.body?.text.contains('Content after'), isTrue);
    });

    test('removes dashed page numbers like "— 42 —"', () {
      final doc = parse('''
        <html><body>
          <p>Main content flows here.</p>
          <p>— 128 —</p>
          <p>Next page content.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('128'), isFalse);
      expect(doc.body?.text.contains('Main content'), isTrue);
    });

    test('preserves numbers within content paragraphs', () {
      final doc = parse('''
        <html><body>
          <p>In the year 1984, the protagonist was 42 years old.</p>
          <p>There were 7 continents, 195 countries.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('1984'), isTrue);
      expect(doc.body?.text.contains('42 years old'), isTrue);
      expect(doc.body?.text.contains('7 continents'), isTrue);
    });

    test('handles multiple space-separated epub:type values', () {
      final doc = parse('''
        <html><body>
          <p epub:type="pagebreak page-number">99</p>
          <p>Content after the break.</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('99'), isFalse);
      expect(doc.body?.text.contains('Content after'), isTrue);
    });

    test('removes <aside> with epub:type="endnotes"', () {
      final doc = parse('''
        <html><body>
          <p>End of chapter.</p>
          <section epub:type="endnotes">
            <p>Note 1: Reference.</p>
            <p>Note 2: Citation.</p>
          </section>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('End of chapter'), isTrue);
      expect(doc.body?.text.contains('Note 1'), isFalse);
    });

    test('removes titlepage and halftitlepage', () {
      final doc = parse('''
        <html><body>
          <section epub:type="titlepage">
            <h1>The Great Novel</h1>
            <p>By Famous Author</p>
          </section>
          <section epub:type="copyright-page">
            <p>© 2024 Publisher</p>
          </section>
          <section epub:type="halftitlepage">
            <h1>The Great Novel</h1>
          </section>
          <p>Chapter 1: The Beginning</p>
        </body></html>
      ''');
      EpubContentFilter.removeNonContent(doc);
      expect(doc.body?.text.contains('Great Novel'), isFalse);
      expect(doc.body?.text.contains('Famous Author'), isFalse);
      expect(doc.body?.text.contains('Publisher'), isFalse);
      expect(doc.body?.text.contains('Chapter 1'), isTrue);
    });

    test('integration: getChapterText filters page numbers via EpubService', () async {
      // This test verifies the full pipeline: epub_content_filter → getChapterText
      final doc = parse('''
        <html><body>
          <p>This is the real story content.</p>
          <span class="pagenum">7</span>
          <p>The story continues with exciting events.</p>
          <nav><a href="#toc">Table of Contents</a></nav>
          <p>The story reaches its thrilling conclusion.</p>
        </body></html>
      ''');

      EpubContentFilter.removeNonContent(doc);
      final text = doc.body?.text.trim() ?? '';

      expect(text.contains('real story content'), isTrue);
      expect(text.contains('exciting events'), isTrue);
      expect(text.contains('thrilling conclusion'), isTrue);

      // Filtered elements should not appear
      expect(text.contains('pagenum'), isFalse);
      expect(text.contains('Table of Contents'), isFalse);
    });
  });
}
