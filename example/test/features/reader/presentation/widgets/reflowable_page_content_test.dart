import 'dart:async';

import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/bookshelf/data/database.dart';
import 'package:real_page_flip_example/features/reader/domain/reader_settings.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reflowable_page_content.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_provider.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_service.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

// ---------------------------------------------------------------------------
// Fake TTS service for testing the highlight stream
// ---------------------------------------------------------------------------

class _FakeTtsService extends SupertonicTtsService {
  final _hlController = StreamController<TtsWordHighlight?>.broadcast();

  @override
  Stream<TtsWordHighlight?> get highlightStream => _hlController.stream;

  void emitHighlight(TtsWordHighlight? hl) {
    _hlController.add(hl);
  }

  @override
  Future<void> stop() async {
    // no-op in test
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    // no-op in test
  }

  @override
  void dispose() {
    _hlController.close();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _testBook = Book(
  id: 'test-book',
  title: 'Test Book Title',
  author: 'Test Author',
  filePath: 'test/book.epub',
  addedAt: DateTime(2024, 1, 1),
);

final _chapter = EpubChapter()
  ..Title = 'Chapter 1'
  ..HtmlContent = 'Hello world. This is a test page.';

const _pageText = 'Hello world. This is a test page.';

final _baseState = ReaderState(
  book: _testBook,
  chapters: [_chapter],
  currentChapterIndex: 0,
  pages: [_pageText],
  currentPageIndex: 0,
  isLoading: false,
);

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget buildPageContent({
  required ReaderState state,
  int index = 0,
  ReaderThemeData theme = ReaderThemeData.cream,
  SupertonicTtsService? ttsService,
}) {
  final effectiveTts = ttsService ?? _FakeTtsService();

  return TranslationProvider(
    child: ProviderScope(
      overrides: [supertonicTtsProvider.overrideWithValue(effectiveTts)],
      child: MaterialApp(
        home: Scaffold(
          body: ReflowablePageContent(state: state, theme: theme, index: index),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReflowablePageContent', () {
    testWidgets('renders empty container when pages is empty', (tester) async {
      final state = _baseState.copyWith(pages: <String>[]);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      // Should render the empty Container (no text, no page counter)
      expect(find.text('Hello world'), findsNothing);
      expect(find.text('Test Book Title'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty container when index is out of bounds', (
      tester,
    ) async {
      final state = _baseState.copyWith(pages: [_pageText]);

      await tester.pumpWidget(buildPageContent(state: state, index: 5));
      await tester.pump();

      expect(find.text('Hello world'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders page text content', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.text('Hello world. This is a test page.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders chapter title', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.text('Chapter 1'), findsOneWidget);
    });

    testWidgets('renders book title', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.text('Test Book Title'), findsOneWidget);
    });

    testWidgets('renders page counter', (tester) async {
      final state = _baseState.copyWith(pages: [_pageText]);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      // Page counter shows "1 / 1" for single page
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('page counter reflects total pages and current index', (
      tester,
    ) async {
      final state = _baseState.copyWith(
        pages: ['page one', 'page two', 'page three'],
      );

      await tester.pumpWidget(buildPageContent(state: state, index: 1));
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('renders without error when chapter title is empty string', (
      tester,
    ) async {
      final chapter = EpubChapter()
        ..Title = ''
        ..HtmlContent = 'Content';
      final state = _baseState.copyWith(
        chapters: [chapter],
        pages: ['Content'],
      );

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      // The `??` operator only falls back on null, not empty string,
      // so the title Text widget renders with an empty string.
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with highlighted text', (tester) async {
      final now = DateTime(2024, 1, 1);
      final highlight = Highlight(
        id: 1,
        bookId: 'test-book',
        chapterIndex: 0,
        startOffset: 0,
        endOffset: 5,
        selectedText: 'Hello',
        highlightColor: 'FFD48F',
        note: null,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );

      final chapter = EpubChapter()
        ..Title = 'Chapter 1'
        ..HtmlContent = 'Hello world. This is a test page.';
      final state = _baseState.copyWith(
        chapters: [chapter],
        pages: ['Hello world. This is a test page.'],
        highlights: [highlight],
      );

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      // The text is rendered via SelectableText.rich with spans
      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with multiple highlights on same page', (
      tester,
    ) async {
      final now = DateTime(2024, 1, 1);
      final highlights = [
        Highlight(
          id: 1,
          bookId: 'test-book',
          chapterIndex: 0,
          startOffset: 0,
          endOffset: 5,
          selectedText: 'Hello',
          highlightColor: 'FFD48F',
          note: null,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        Highlight(
          id: 2,
          bookId: 'test-book',
          chapterIndex: 0,
          startOffset: 28,
          endOffset: 32,
          selectedText: 'test',
          highlightColor: 'A2D497',
          note: null,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
      ];
      final chapter = EpubChapter()
        ..Title = 'Chapter 1'
        ..HtmlContent = 'Hello world. This is a test page.';
      final state = _baseState.copyWith(
        chapters: [chapter],
        pages: ['Hello world. This is a test page.'],
        highlights: highlights,
      );

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      expect(find.textContaining('Hello'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TTS word highlighting stream updates widget', (tester) async {
      final fakeTts = _FakeTtsService();
      final chapter = EpubChapter()
        ..Title = 'Chapter 1'
        ..HtmlContent = 'Hello world. This is a test page.';
      final state = _baseState.copyWith(
        chapters: [chapter],
        pages: ['Hello world. This is a test page.'],
      );

      await tester.pumpWidget(
        buildPageContent(state: state, ttsService: fakeTts),
      );
      await tester.pump();

      // Push a TTS highlight via the stream to verify the StreamBuilder updates
      fakeTts.emitHighlight(TtsWordHighlight(0, 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Clear the TTS highlight
      fakeTts.emitHighlight(null);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('TTS highlight for different page index is ignored', (
      tester,
    ) async {
      final fakeTts = _FakeTtsService();
      final state = _baseState.copyWith(pages: [_pageText]);

      await tester.pumpWidget(
        buildPageContent(state: state, ttsService: fakeTts),
      );
      await tester.pump();

      // When activeTtsPageIndex differs from index, highlight is ignored
      fakeTts.emitHighlight(TtsWordHighlight(0, 5));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('font size setting applies without error', (tester) async {
      const settings = ReaderSettings(fontSize: 24.0);
      final state = _baseState.copyWith(settings: settings);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('line height setting applies without error', (tester) async {
      const settings = ReaderSettings(lineHeight: 2.0);
      final state = _baseState.copyWith(settings: settings);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('serif font family applies without error', (tester) async {
      const settings = ReaderSettings(fontFamily: 'serif');
      final state = _baseState.copyWith(settings: settings);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles empty highlights list gracefully', (tester) async {
      final state = _baseState.copyWith(highlights: <Highlight>[]);

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      expect(find.text('Hello world. This is a test page.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles highlight on different chapter index', (tester) async {
      final now = DateTime(2024, 1, 1);
      final highlight = Highlight(
        id: 1,
        bookId: 'test-book',
        chapterIndex: 5, // different from currentChapterIndex (0)
        startOffset: 0,
        endOffset: 5,
        selectedText: 'Hello',
        highlightColor: 'FFD48F',
        note: null,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final chapter = EpubChapter()
        ..Title = 'Chapter 1'
        ..HtmlContent = 'Hello world. This is a test page.';
      final state = _baseState.copyWith(
        chapters: [chapter],
        pages: ['Hello world. This is a test page.'],
        highlights: [highlight],
      );

      await tester.pumpWidget(buildPageContent(state: state));
      await tester.pump();

      // Highlight on another chapter should be filtered out
      expect(find.textContaining('Hello world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SelectableText widget is present in the tree', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('Expanded widgets are present', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      // Two Expanded widgets: one for LayoutBuilder, one inside Row for book title
      expect(find.byType(Expanded), findsNWidgets(2));
    });

    testWidgets('SingleChildScrollView is present', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('LayoutBuilder is present', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('GestureDetector wraps the scrollable content', (tester) async {
      await tester.pumpWidget(buildPageContent(state: _baseState));
      await tester.pump();

      expect(find.byType(GestureDetector), findsOneWidget);
    });
  });
}
