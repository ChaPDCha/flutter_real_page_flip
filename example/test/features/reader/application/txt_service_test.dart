import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/application/txt_service.dart';

void main() {
  group('TxtService Tests', () {
    late TxtService service;
    late Directory tempDir;

    setUp(() async {
      service = TxtService();
      tempDir = await Directory.systemTemp.createTemp();
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    group('readFile encoding', () {
      test('reads plain UTF-8 file without BOM', () async {
        final file = File('${tempDir.path}/utf8.txt');
        await file.writeAsString('안녕하세요', encoding: utf8);

        final content = await TxtService.readFile(file.path);
        expect(content, equals('안녕하세요'));
      });

      test('reads UTF-8 file with BOM', () async {
        final file = File('${tempDir.path}/bom.txt');
        final bom = [0xEF, 0xBB, 0xBF];
        final encoded = utf8.encode('Hello BOM');
        await file.writeAsBytes([...bom, ...encoded]);

        final content = await TxtService.readFile(file.path);
        expect(content, equals('Hello BOM'));
      });

      test('falls back when UTF-8 decode fails', () async {
        // Write latin1-encoded text (0xE9 = é in latin1, invalid UTF-8 start)
        final file = File('${tempDir.path}/latin1.txt');
        await file.writeAsBytes([0xE9, 0x63, 0x61, 0x66, 0xE9]);

        // Should not throw — degraded characters are acceptable
        final content = await TxtService.readFile(file.path);
        expect(content, isNotEmpty);
      });
    });

    group('parseChapters', () {
      test('splits text based on chapter markers', () async {
        final file = File('${tempDir.path}/marked_book.txt');
        await file.writeAsString('''
Prologue text before any marker.
Chapter 1: The Beginning
This is the body of chapter one.
제 2장: 새로운 여정
이곳은 제 2장의 본문입니다.
# Chapter 3: Markdown Style
This is markdown chapter content.
''');

        final chapters = await service.parseChapters(file.path);

        expect(chapters.length, equals(4));
        expect(chapters[0].Title, equals('프롤로그'));
        expect(chapters[0].HtmlContent, contains('Prologue text'));

        expect(chapters[1].Title, equals('Chapter 1: The Beginning'));
        expect(
          chapters[1].HtmlContent,
          contains('This is the body of chapter one.'),
        );

        expect(chapters[2].Title, equals('제 2장: 새로운 여정'));
        expect(chapters[2].HtmlContent, contains('이곳은 제 2장의 본문입니다.'));

        expect(chapters[3].Title, equals('# Chapter 3: Markdown Style'));
        expect(
          chapters[3].HtmlContent,
          contains('This is markdown chapter content.'),
        );
      });

      test('does not treat hash in middle of line as chapter marker', () async {
        final file = File('${tempDir.path}/hash_in_text.txt');
        await file.writeAsString(
          'This product is #1 in sales.\n'
          'Chapter 1: Real Chapter\n'
          'Content here.\n',
        );

        final chapters = await service.parseChapters(file.path);

        // "This product is #1 in sales." should NOT be a chapter marker
        expect(chapters.length, equals(2)); // prologue + chapter 1
        expect(chapters[0].Title, equals('프롤로그'));
        expect(chapters[0].HtmlContent, contains('#1 in sales'));
        expect(chapters[1].Title, contains('Chapter 1'));
      });

      test('handles consecutive chapter markers without body', () async {
        final file = File('${tempDir.path}/consecutive_chapters.txt');
        await file.writeAsString(
          'Chapter 1\n'
          'Chapter 2\n'
          'Some content for chapter 2.\n'
          'Chapter 3\n'
          'Content for 3.\n',
        );

        final chapters = await service.parseChapters(file.path);

        expect(chapters.length, equals(3));
        // Chapter 1 has empty body
        expect(chapters[0].Title, equals('Chapter 1'));
        // Chapter 2 includes "Some content for chapter 2."
        expect(chapters[1].HtmlContent, contains('Some content for chapter 2'));
        // Chapter 3 includes content
        expect(chapters[2].HtmlContent, contains('Content for 3.'));
      });

      test(
        'splits long files without markers into virtual 15,000 char blocks',
        () async {
          final file = File('${tempDir.path}/long_unmarked_book.txt');
          final longText = 'A' * 32000;
          await file.writeAsString(longText);

          final chapters = await service.parseChapters(file.path);

          expect(chapters.length, equals(3));
          expect(chapters[0].Title, equals('파트 1'));
          expect(chapters[1].Title, equals('파트 2'));
          expect(chapters[2].Title, equals('파트 3'));
        },
      );

      test('short file without markers becomes single chapter', () async {
        final file = File('${tempDir.path}/short_unmarked.txt');
        await file.writeAsString('Short content without any chapter markers.');

        final chapters = await service.parseChapters(file.path);

        expect(chapters.length, equals(1));
        expect(chapters[0].Title, equals('본문'));
        expect(chapters[0].HtmlContent, contains('Short content'));
      });

      test('handles empty files gracefully', () async {
        final file = File('${tempDir.path}/empty_book.txt');
        await file.writeAsString('   ');

        final chapters = await service.parseChapters(file.path);

        expect(chapters.length, equals(1));
        expect(chapters[0].Title, equals('빈 책'));
      });

      test('_convertToHtml preserves paragraph structure', () async {
        final file = File('${tempDir.path}/paragraphs.txt');
        await file.writeAsString('First line.\n\nSecond line.\nThird line.');

        final chapters = await service.parseChapters(file.path);

        expect(chapters.length, equals(1));
        final html = chapters[0].HtmlContent;
        expect(html, contains('<p>First line.</p>'));
        expect(html, contains('<p>Second line.</p>'));
        expect(html, contains('<p>Third line.</p>'));
      });
    });
  });
}
