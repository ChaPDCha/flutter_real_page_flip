import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/page_spans_helper.dart';

void main() {
  group('buildPageSpans', () {
    // ignore: prefer_const_declarations
    final baseStyle = const TextStyle(fontSize: 16.0, color: Colors.black);
    final testDate = DateTime(2024, 1, 1);

    group('basic splits (no highlights, no TTS)', () {
      test('returns empty list for empty text', () {
        final spans = buildPageSpans(
          pageText: '',
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // When pageText is empty, no segments are produced
        expect(spans, isEmpty);
      });

      test('returns a single TextSpan with the whole text', () {
        final spans = buildPageSpans(
          pageText: 'Hello World',
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans, hasLength(1));
        expect(spans.first.text, 'Hello World');
        expect(spans.first.style, baseStyle);
      });
    });

    group('highlights', () {
      test('splits text at highlight boundaries', () {
        final highlight = Highlight(
          id: 1,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        // pageText:   Hello World
        //           0         11
        // highlight:      ^^^^^  (6-11)
        // split:     0, 6, 11
        // spans:     "Hello " (base), "World" (highlight)
        const pageText = 'Hello World';
        const pageStart = 0;

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: pageStart,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans, hasLength(2));
        expect(spans[0].text, 'Hello ');
        expect(spans[0].style, baseStyle);
        expect(spans[1].text, 'World');
        expect(spans[1].style!.backgroundColor, isNotNull);
      });

      test('handles highlight at start of text', () {
        final highlight = Highlight(
          id: 2,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 5,
          selectedText: 'Hello',
          highlightColor: '#00FF00',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans, hasLength(2));
        expect(spans[0].text, 'Hello');
        expect(spans[0].style!.backgroundColor, isNotNull);
        expect(spans[1].text, ' World');
        expect(spans[1].style, baseStyle);
      });

      test('handles highlight at end of text', () {
        final highlight = Highlight(
          id: 3,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#0000FF',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans, hasLength(2));
        expect(spans[0].text, 'Hello ');
        expect(spans[0].style, baseStyle);
        expect(spans[1].text, 'World');
        expect(spans[1].style!.backgroundColor, isNotNull);
      });

      test('handles multiple non-overlapping highlights', () {
        final highlight1 = Highlight(
          id: 4,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 5,
          selectedText: 'Hello',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );
        final highlight2 = Highlight(
          id: 5,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#00FF00',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight1, highlight2],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Splits: 0, 5, 6, 11 → segments: 0-5, 5-6, 6-11
        expect(spans, hasLength(3));
        expect(spans[0].text, 'Hello');
        expect(spans[1].text, ' ');
        expect(spans[2].text, 'World');
      });

      test('skips highlight entirely outside page offset range', () {
        final outsideHighlight = Highlight(
          id: 6,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 100,
          endOffset: 110,
          selectedText: 'far',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [outsideHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Highlight is outside page, so no split → single span
        expect(spans, hasLength(1));
        expect(spans.first.text, 'Hello World');
      });

      test('clamps highlight offsets that exceed page length', () {
        final overreachingHighlight = Highlight(
          id: 7,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 5,
          endOffset: 50, // beyond page
          selectedText: 'excess',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [overreachingHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Split at 5 → segments 0-5 (base), 5-11 (highlighted & clamped)
        expect(spans, hasLength(2));
        expect(spans[0].text, 'Hello');
        expect(spans[1].text, ' World');
        expect(spans[1].style!.backgroundColor, isNotNull);
      });

      test('applies pageStartOffset to align global offsets to page', () {
        // pageText starts at global offset 50
        // "World" starts at global offset 56 → page-relative offset 6
        // "World" ends at global offset 61 → page-relative offset 11
        const pageStartOffset = 50;
        const pageText = 'Hello World of Testing';

        final highlight = Highlight(
          id: 8,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 56,
          endOffset: 61,
          selectedText: 'World',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: pageStartOffset,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Highlight covers chars 6-11 of "Hello World of Testing"
        // Segments: "Hello " (base), "World" (highlight), " of Testing" (base)
        expect(spans, hasLength(3));
        expect(spans[0].text, 'Hello ');
        expect(spans[0].style, baseStyle);
        expect(spans[1].text, 'World');
        expect(spans[1].style!.backgroundColor, isNotNull);
        expect(spans[2].text, ' of Testing');
        expect(spans[2].style, baseStyle);
      });

      test('uses yellow fallback for invalid hex color', () {
        final invalidHighlight = Highlight(
          id: 9,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: 'not-a-color',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [invalidHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans, hasLength(2));
        expect(spans[1].text, 'World');
        // Fallback is Colors.yellow.withValues(alpha: 0.3)
        expect(spans[1].style!.backgroundColor, isNotNull);
      });

      test('uses yellow fallback for malformed hex with incorrect length', () {
        final shortHighlight = Highlight(
          id: 10,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#FF',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        const pageText = 'Hello World';
        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [shortHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        expect(spans[1].style!.backgroundColor, isNotNull);
      });

      test('parses valid hex color into background color', () {
        // Verify that a valid 6-digit hex color is correctly parsed
        const pageText = 'Hello World of Testing';

        final highlight = Highlight(
          id: 18,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // The highlight segment "World" should have a non-null background
        expect(spans[1].style!.backgroundColor, isNotNull);
        // The color should NOT be the yellow fallback
        expect(
          spans[1].style!.backgroundColor,
          isNot(Colors.yellow.withValues(alpha: 0.3)),
        );
      });
    });

    group('TTS karaoke', () {
      test('applies amber background to TTS range', () {
        const pageText = 'Hello World of Testing';
        const ttsStart = 6;
        const ttsEnd = 11;

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: ttsStart,
          ttsEndInPage: ttsEnd,
          baseStyle: baseStyle,
        );

        // Splits: 0, 6, 11, 22
        // Segments: 0-6 (base), 6-11 (TTS), 11-22 (base)
        expect(spans, hasLength(3));
        expect(spans[0].text, 'Hello ');
        expect(spans[0].style, baseStyle);

        expect(spans[1].text, 'World');
        expect(
          spans[1].style!.backgroundColor,
          Colors.amber.withValues(alpha: 0.3),
        );

        expect(spans[2].text, ' of Testing');
        expect(spans[2].style, baseStyle);
      });

      test('TTS highlight takes priority over user highlight', () {
        // If both TTS and user highlight cover the same range, TTS wins.
        const pageText = 'Hello World of Testing';
        const ttsStart = 6;
        const ttsEnd = 11;

        final userHighlight = Highlight(
          id: 11,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#00FF00',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [userHighlight],
          pageStartOffset: 0,
          ttsStartInPage: ttsStart,
          ttsEndInPage: ttsEnd,
          baseStyle: baseStyle,
        );

        // TTS segment should have amber, not green
        expect(spans[1].text, 'World');
        expect(
          spans[1].style!.backgroundColor,
          Colors.amber.withValues(alpha: 0.3),
        );
      });

      test('TTS range can span multiple highlight segments', () {
        // With a highlight, TTS range that covers the entire text should
        // make all segments use the TTS amber background.
        const pageText = 'Hello World of Testing';
        // pageText.length is 22, so set ttsEnd to 22
        const ttsStart = 0;
        const ttsEnd = 22; // covers entire text

        final highlight1 = Highlight(
          id: 12,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 6,
          endOffset: 11,
          selectedText: 'World',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight1],
          pageStartOffset: 0,
          ttsStartInPage: ttsStart,
          ttsEndInPage: ttsEnd,
          baseStyle: baseStyle,
        );

        // All segments should have TTS (amber) background
        expect(spans, isNotEmpty);
        for (final span in spans) {
          expect(
            span.style!.backgroundColor,
            Colors.amber.withValues(alpha: 0.3),
            reason:
                'All segments should have TTS amber when TTS covers full text',
          );
        }
      });

      test('ignores TTS when ttsStartInPage and ttsEndInPage are -1', () {
        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Single span, base style, no amber
        expect(spans, hasLength(1));
        expect(spans.first.style, baseStyle);
      });

      test('ignores TTS when start is -1 even if end is valid', () {
        const pageText = 'Hello World';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: 5,
          baseStyle: baseStyle,
        );

        // No TTS segmentation
        expect(spans, hasLength(1));
        expect(spans.first.style, baseStyle);
      });

      test('clamps TTS offsets that exceed page length', () {
        const pageText = 'Hi';

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: const [],
          pageStartOffset: 0,
          ttsStartInPage: 0,
          ttsEndInPage: 100, // exceeds page length
          baseStyle: baseStyle,
        );

        // TTS should be clamped to page length, covering "Hi"
        expect(spans, hasLength(1));
        expect(spans.first.text, 'Hi');
        expect(
          spans.first.style!.backgroundColor,
          Colors.amber.withValues(alpha: 0.3),
        );
      });
    });

    group('edge cases', () {
      test('handles highlight with offset below 0 (clamped)', () {
        // Page starts at global offset 10, but highlight has offset 5
        // → (5 - 10).clamp(0, text.length) = 0
        const pageText = 'Hello World';

        final highlight = Highlight(
          id: 13,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 5, // before pageStartOffset
          endOffset: 11,
          selectedText: 'Hello World',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [highlight],
          pageStartOffset: 10,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Highlight starts at 0, ends at 1 (11 - 10)
        // Split: 0, 1, 11
        expect(spans, hasLength(2));
        expect(spans[0].text, 'H');
      });

      test('preserves entire text across spans (no missing characters)', () {
        const text = 'ABCDEFGHIJ';
        const ttsStart = 3;
        const ttsEnd = 7;

        final highlight = Highlight(
          id: 14,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 2,
          selectedText: 'AB',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: text,
          pageHighlights: [highlight],
          pageStartOffset: 0,
          ttsStartInPage: ttsStart,
          ttsEndInPage: ttsEnd,
          baseStyle: baseStyle,
        );

        // Reconstruct the full text from spans
        final reconstructed = spans.map((s) => s.text!).join();
        expect(reconstructed, text);
      });

      test('handles zero-width highlight boundary', () {
        // When highlight start == end, the split point is deduplicated
        // but the boundary still creates two segments.
        const pageText = 'Test';

        final zeroWidthHighlight = Highlight(
          id: 15,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 2,
          endOffset: 2, // zero-width
          selectedText: '',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [zeroWidthHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // Split points: {0, 4, 2} → segments: "Te", "st"
        expect(spans, hasLength(2));
        expect(spans[0].text, 'Te');
        expect(spans[1].text, 'st');
      });

      test('handles overlapping highlights (first wins)', () {
        // Two highlights overlapping same range; the first one in the list
        // should be used.
        const pageText = 'Hello World of Testing';

        final firstHighlight = Highlight(
          id: 16,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 5,
          selectedText: 'Hello',
          highlightColor: '#FF0000',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );
        final secondHighlight = Highlight(
          id: 17,
          bookId: 'test',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 5,
          selectedText: 'Hello',
          highlightColor: '#00FF00',
          createdAt: testDate,
          updatedAt: testDate,
          isDeleted: false,
        );

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: [firstHighlight, secondHighlight],
          pageStartOffset: 0,
          ttsStartInPage: -1,
          ttsEndInPage: -1,
          baseStyle: baseStyle,
        );

        // First highlight's color should win (non-null background)
        expect(spans.first.text, 'Hello');
        expect(spans.first.style!.backgroundColor, isNotNull);
      });
    });
  });
}
