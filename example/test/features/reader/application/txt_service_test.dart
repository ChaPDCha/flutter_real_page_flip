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

    test('parseChapters splits text based on chapter markers', () async {
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

      // We expect 4 chapters: Prologue, Chapter 1, Chapter 2, Chapter 3
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

    test(
      'parseChapters splits long files without markers into virtual 15,000 char blocks',
      () async {
        final file = File('${tempDir.path}/long_unmarked_book.txt');
        // Create text of 32,000 characters
        final longText = 'A' * 32000;
        await file.writeAsString(longText);

        final chapters = await service.parseChapters(file.path);

        // We expect 3 chapters: 15,000 + 15,000 + 2,000 chars
        expect(chapters.length, equals(3));
        expect(chapters[0].Title, equals('파트 1'));
        expect(chapters[1].Title, equals('파트 2'));
        expect(chapters[2].Title, equals('파트 3'));
      },
    );

    test('parseChapters handles empty files gracefully', () async {
      final file = File('${tempDir.path}/empty_book.txt');
      await file.writeAsString('   ');

      final chapters = await service.parseChapters(file.path);

      expect(chapters.length, equals(1));
      expect(chapters[0].Title, equals('빈 책'));
    });
  });
}
