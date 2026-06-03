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

    test('getChapterText filters script/style/head tags and extracts clean text', () {
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
