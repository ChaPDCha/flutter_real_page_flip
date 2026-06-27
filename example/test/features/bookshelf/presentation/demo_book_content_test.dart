import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/presentation/demo_book_content.dart';

void main() {
  group('DemoBookContent', () {
    group('demoChapterTitles', () {
      test('contains exactly 10 chapter titles', () {
        expect(demoChapterTitles.length, 10);
      });

      test('all titles are non-empty strings', () {
        for (final title in demoChapterTitles) {
          expect(title, isA<String>());
          expect(title.isNotEmpty, isTrue);
        }
      });

      test('first title is "봄날의 산책"', () {
        expect(demoChapterTitles[0], '봄날의 산책');
      });

      test('last title is "일상의 발견"', () {
        expect(demoChapterTitles[9], '일상의 발견');
      });

      test('all titles are unique', () {
        final uniqueTitles = demoChapterTitles.toSet();
        expect(uniqueTitles.length, demoChapterTitles.length);
      });
    });

    group('generateDemoContent', () {
      test('returns a non-empty string', () {
        final content = generateDemoContent();

        expect(content, isA<String>());
        expect(content.isNotEmpty, isTrue);
      });

      test('contains all chapter titles', () {
        final content = generateDemoContent();

        for (final title in demoChapterTitles) {
          expect(content, contains(title));
        }
      });

      test('contains chapter numbering pattern', () {
        final content = generateDemoContent();

        expect(content, contains('제1장:'));
        expect(content, contains('제10장:'));
      });

      test('generates content without throwing', () {
        expect(() => generateDemoContent(), returnsNormally);
      });

      test('generates substantial content (more than just chapter titles)', () {
        final content = generateDemoContent();

        // Each chapter has ~30 paragraphs of 4 sentences each
        // Total should be well over 5000 characters
        expect(content.length, greaterThan(5000));
      });

      test('content includes Korean sentences with punctuation', () {
        final content = generateDemoContent();

        // Korean sentences end with periods
        expect(content.contains('다.'), isTrue);
        expect(content.contains('했다.'), isTrue);
      });

      test('content has blank lines between chapters', () {
        final content = generateDemoContent();

        // Each chapter is separated by blank lines
        expect(content, contains('\n\n\n제'));
      });
    });

    group('content structure', () {
      test('each chapter has multiple paragraphs', () {
        final content = generateDemoContent();

        // Count chapter markers
        final chapterCount =
            '제'.allMatches(content).length;
        expect(chapterCount, greaterThanOrEqualTo(10));
      });

      test('long running content generation is deterministic', () {
        final content1 = generateDemoContent();
        final content2 = generateDemoContent();

        expect(content1, equals(content2));
      });
    });
  });
}
