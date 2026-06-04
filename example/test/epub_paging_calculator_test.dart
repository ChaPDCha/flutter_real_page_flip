import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/reader/application/epub_paging_calculator.dart';

void main() {
  // Ensure Flutter's test binding is initialized to mock text measurement
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EpubPagingCalculator - Senior Edge Case Tests', () {
    const double defaultWidth = 375.0; // Standard smartphone width
    const double defaultHeight = 667.0; // Standard smartphone height
    const TextStyle baseStyle = TextStyle(fontFamily: 'serif');

    test('Empty text returns single empty page', () {
      final pages = EpubPagingCalculator.splitIntoPages(
        text: '',
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages, equals(['']));
    });

    testWidgets('Whitespace gaps do not produce blank pages', (WidgetTester tester) async {
      const text = 'A\n\n\n\n\n\n\n\n\n\n\n\n\n\nB';

      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: 120.0,
        viewportHeight: 30.0,
        fontSize: 16.0,
        lineHeight: 1.6,
        baseStyle: baseStyle,
      );

      expect(pages.every((page) => page.trim().isNotEmpty), isTrue);
      expect(pages.join(), equals('AB'));
    });

    test('Whitespace-only text returns single empty page', () {
      final pages = EpubPagingCalculator.splitIntoPages(
        text: '   \n  \t ',
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages, equals(['']));
    });

    testWidgets('Short text fits into a single page', (WidgetTester tester) async {
      const text = 'Hello world! This is a simple test text.';
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages.length, equals(1));
      expect(pages.first, equals(text));
    });

    testWidgets('Long text is split into multiple pages', (WidgetTester tester) async {
      final buffer = StringBuffer();
      for (int i = 0; i < 30; i++) {
        buffer.writeln('Paragraph $i. Flutter is a premium SDK for cross-platform apps.');
      }
      final text = buffer.toString();

      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages.length, greaterThan(1));
      final reassembledText = pages.join(' ');
      expect(reassembledText.contains('Paragraph 0'), isTrue);
      expect(reassembledText.contains('Paragraph 29'), isTrue);
    });

    testWidgets('Larger font size increases page count', (WidgetTester tester) async {
      final buffer = StringBuffer();
      for (int i = 0; i < 15; i++) {
        buffer.writeln('Paragraph $i. Checking dynamic scale adjustments.');
      }
      final text = buffer.toString();

      final pagesSmall = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 12.0,
        lineHeight: 1.1,
        baseStyle: baseStyle,
      );

      final pagesLarge = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 28.0,
        lineHeight: 1.8,
        baseStyle: baseStyle,
      );

      expect(pagesLarge.length, greaterThan(pagesSmall.length));
    });

    testWidgets('Tries to break at space or newline boundary instead of mid-word', (WidgetTester tester) async {
      const text = 'WordOne WordTwo WordThree WordFour WordFive WordSix WordSeven WordEight';
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: 120.0, // Force wrapping/splitting
        viewportHeight: 45.0,
        fontSize: 14.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages.length, greaterThan(1));
      for (final page in pages) {
        expect(
          page.isEmpty || page.startsWith('Word'), 
          isTrue, 
          reason: 'Page "$page" should start with Word to respect boundaries.'
        );
      }
    });

    // --- SENIOR DEVELOPER EDGE CASES ---

    testWidgets('Extreme Viewport Constraint (No Infinite Loop)', (WidgetTester tester) async {
      // If viewport width/height is extremely small (e.g. 1.0) and font size is large,
      // the calculator must not loop infinitely and must advance character-by-character.
      const text = 'Extremely small viewport test with long text.';
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: 1.0,
        viewportHeight: 1.0,
        fontSize: 48.0,
        lineHeight: 1.5,
        baseStyle: baseStyle,
      );

      // Should split text and make forward progress instead of hanging
      expect(pages.length, greaterThan(0));
      expect(pages.join(''), equals(text.replaceAll(RegExp(r'\s+'), '')));
    });

    testWidgets('No-Space Continuous Long String', (WidgetTester tester) async {
      // Testing text with no spaces (e.g., long URL, serial token, base64 data)
      final text = 'A' * 200; // Continuous character string
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: 80.0, // Force split
        viewportHeight: 40.0,
        fontSize: 14.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(pages.length, greaterThan(1));
      expect(pages.join(''), equals(text));
    });

    testWidgets('Unicode Surrogate Pair / Emoji Integrity Protection', (WidgetTester tester) async {
      // Rocket emoji 🚀 is encoded as surrogate pair "\uD83D\uDE80"
      // If split arbitrary, it breaks the unicode character and creates rendering issues.
      // We will place emojis at locations that will likely fall on page split boundaries.
      final buffer = StringBuffer();
      for (int i = 0; i < 50; i++) {
        buffer.write('🚀');
      }
      final text = buffer.toString();

      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: 60.0,
        viewportHeight: 30.0,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      // Verify that every single page contains only whole rocket emojis (no split surrogate code units)
      for (final page in pages) {
        if (page.isEmpty) continue;
        for (int i = 0; i < page.length; i++) {
          final codeUnit = page.codeUnitAt(i);
          // High surrogate: 0xD800 - 0xDBFF
          if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
            expect(i + 1, lessThan(page.length), reason: 'High surrogate found at end of page: broken emoji!');
            final nextCodeUnit = page.codeUnitAt(i + 1);
            expect(nextCodeUnit >= 0xDC00 && nextCodeUnit <= 0xDFFF, isTrue, 
                reason: 'High surrogate not followed by a low surrogate!');
            i++; // skip low surrogate
          } else {
            // Low surrogate: 0xDC00 - 0xDFFF
            expect(codeUnit >= 0xDC00 && codeUnit <= 0xDFFF, isFalse, 
                reason: 'Orphan low surrogate found: emoji split!');
          }
        }
      }
    });

    test(
      'splitIntoPagesAsync paginates long chapters on root isolate',
      () async {
        final text = 'word ' * 1700;
        expect(text.length, greaterThan(8000));

        final pages = await EpubPagingCalculator.splitIntoPagesAsync(
          text: text,
          viewportWidth: defaultWidth,
          viewportHeight: defaultHeight,
          fontSize: 16.0,
          lineHeight: 1.2,
          baseStyle: baseStyle,
        );

        expect(pages, isNotEmpty);
        expect(pages.every((page) => page.isNotEmpty), isTrue);
      },
    );

    test('splitIntoPages returns cached result for identical inputs', () {
      EpubPagingCalculator.clearCache();
      const text = 'Cached paging should reuse the same page boundaries.';

      final first = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );
      final second = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );

      expect(identical(first, second), isTrue);
    });

    testWidgets('High-Load Performance Benchmark Stress Test', (WidgetTester tester) async {
      // Benchmark: splitting a chapter with 100,000 characters
      final buffer = StringBuffer();
      for (int i = 0; i < 1500; i++) {
        buffer.write('This is paragraph $i of the stress test benchmark. ');
      }
      final text = buffer.toString();

      final stopwatch = Stopwatch()..start();
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: defaultWidth,
        viewportHeight: defaultHeight,
        fontSize: 16.0,
        lineHeight: 1.2,
        baseStyle: baseStyle,
      );
      
      stopwatch.stop();
      debugPrint('Benchmark: Split ${text.length} chars into ${pages.length} pages in ${stopwatch.elapsedMilliseconds}ms');

      expect(pages.length, greaterThan(10));
      // World-class performance requirement: should finish parsing 80k characters in under 2000ms in virtual testing environments
      expect(stopwatch.elapsedMilliseconds, lessThan(2000), 
          reason: 'Paging calculator took too long: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
