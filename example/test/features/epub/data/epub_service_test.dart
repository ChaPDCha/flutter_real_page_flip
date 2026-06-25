import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:epubx/epubx.dart';
import 'package:real_page_flip_example/features/epub/data/epub_service.dart';

class MockEpubChapter extends Mock implements EpubChapter {}

class MockEpubBook extends Mock implements EpubBook {}

void main() {
  group('EpubService Tests', () {
    late EpubService service;

    setUp(() {
      service = EpubService();
    });

    test('getChapterText returns empty string for null or empty HTML', () {
      final chapter = MockEpubChapter();
      when(() => chapter.HtmlContent).thenReturn(null);

      var text = service.getChapterText(chapter);
      expect(text, isEmpty);

      when(() => chapter.HtmlContent).thenReturn('   ');
      text = service.getChapterText(chapter);
      expect(text, isEmpty);
    });

    test(
      'getChapterText filters script/style/head tags and extracts clean text',
      () {
        final chapter = MockEpubChapter();
        const html = '''
        <html>
          <head>
            <style>p { color: red; }</style>
          </head>
          <body>
            <h1>Chapter Title</h1>
            <p>This is the first paragraph.</p>
            <script>alert("hello");</script>
            <div>This is inside a div.</div>
          </body>
        </html>
      ''';
        when(() => chapter.HtmlContent).thenReturn(html);

        final text = service.getChapterText(chapter);

        // Verify script/style content is ignored
        expect(text.contains('alert'), isFalse);
        expect(text.contains('color: red'), isFalse);

        // Verify text is extracted and block structure is preserved (separated by newlines)
        expect(text.contains('Chapter Title'), isTrue);
        expect(text.contains('This is the first paragraph.'), isTrue);
        expect(text.contains('This is inside a div.'), isTrue);
      },
    );

    test('getChapterText keeps text when div only wraps empty layout divs', () {
      final chapter = MockEpubChapter();
      const html = '''
        <body>
          <div class="chapter">
            Chapter body text without paragraph tags.
            <div class="spacer"></div>
          </div>
        </body>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('Chapter body text'), isTrue);
    });

    test('getChapterText skips sub-elements in div to avoid duplication', () {
      final chapter = MockEpubChapter();
      // Outer div contains a p tag. The text should only appear once.
      const html = '''
        <body>
          <div>
            <p>Unique inner paragraph.</p>
          </div>
        </body>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);
      expect(text.trim(), equals('Unique inner paragraph.'));
    });

    test('getChapterText extracts text from HTML5 section elements', () {
      final chapter = MockEpubChapter();
      const html = '''
        <html>
          <body>
            <section class="chapter">
              <h1>Chapter 1</h1>
              <p>First paragraph in a section.</p>
              <p>Second paragraph in a section.</p>
            </section>
          </body>
        </html>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('Chapter 1'), isTrue);
      expect(text.contains('First paragraph in a section.'), isTrue);
      expect(text.contains('Second paragraph in a section.'), isTrue);
    });

    test('getChapterText preserves direct text in wrapper elements', () {
      final chapter = MockEpubChapter();
      const html = '''
        <body>
          <div>
            Direct text in wrapper.
            <p>Paragraph text.</p>
            More direct text after block.
          </div>
        </body>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('Direct text in wrapper.'), isTrue);
      expect(text.contains('Paragraph text.'), isTrue);
      expect(text.contains('More direct text after block.'), isTrue);
    });

    test('getChapterText handles nested section elements', () {
      final chapter = MockEpubChapter();
      const html = '''
        <html>
          <body>
            <section>
              <h1>Main Title</h1>
              <section>
                <h2>Sub Section</h2>
                <p>Nested paragraph.</p>
              </section>
              <p>After nested section.</p>
            </section>
          </body>
        </html>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('Main Title'), isTrue);
      expect(text.contains('Sub Section'), isTrue);
      expect(text.contains('Nested paragraph.'), isTrue);
      expect(text.contains('After nested section.'), isTrue);
    });

    test('getChapterText handles blockquote elements', () {
      final chapter = MockEpubChapter();
      const html = '''
        <body>
          <p>Normal paragraph.</p>
          <blockquote>Quoted text.</blockquote>
          <p>After quote.</p>
        </body>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('Normal paragraph.'), isTrue);
      expect(text.contains('Quoted text.'), isTrue);
      expect(text.contains('After quote.'), isTrue);
    });

    test('getChapterText extracts body text when no block elements found', () {
      final chapter = MockEpubChapter();
      const html = '''
        <body>
          Just bare body text with no block elements.
        </body>
      ''';
      when(() => chapter.HtmlContent).thenReturn(html);

      final text = service.getChapterText(chapter);

      expect(text.contains('bare body text'), isTrue);
    });

    test('getChapterText is cached per chapter object', () {
      final chapter = MockEpubChapter();
      const html = '<html><body><p>Cache test content.</p></body></html>';
      when(() => chapter.HtmlContent).thenReturn(html);

      // First call populates cache
      final first = service.getChapterText(chapter);
      // Replace chapter content to verify cache is used
      when(() => chapter.HtmlContent).thenReturn('<html><body><p>Changed.</p></body></html>');

      // Second call should return cached value (unchanged)
      final second = service.getChapterText(chapter);
      expect(second, equals(first));
      expect(second, contains('Cache test content'));
    });

    test('flattenChapters flattens sub-chapters recursively', () {
      final book = MockEpubBook();

      final subChapter2 = MockEpubChapter();
      when(() => subChapter2.SubChapters).thenReturn([]);

      final subChapter1 = MockEpubChapter();
      when(() => subChapter1.SubChapters).thenReturn([subChapter2]);

      final parentChapter = MockEpubChapter();
      when(() => parentChapter.SubChapters).thenReturn([subChapter1]);

      when(() => book.Chapters).thenReturn([parentChapter]);

      final flatChapters = service.flattenChapters(book);

      expect(flatChapters.length, equals(3));
      expect(flatChapters[0], equals(parentChapter));
      expect(flatChapters[1], equals(subChapter1));
      expect(flatChapters[2], equals(subChapter2));
    });
  });
}
