import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/application/search_service.dart';
import 'package:real_page_flip_example/features/reader/application/search_service_provider.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_search_panel.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

class MockSearchService extends Mock implements SearchService {}

void main() {
  group('ReaderSearchPanel', () {
    late MockSearchService mockSearchService;

    final testBook = Book(
      id: 'test-book',
      title: 'Test Book',
      author: 'Test Author',
      filePath: 'test/book.epub',
      addedAt: DateTime(2024, 1, 1),
    );

    setUp(() {
      mockSearchService = MockSearchService();
      when(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).thenAnswer(
        (_) => SynchronousFuture<List<SearchResult>>(<SearchResult>[]),
      );
    });

    Widget buildPanel({
      Function(int chapterIndex, String query)? onResultSelected,
    }) {
      return TranslationProvider(
        child: ProviderScope(
          overrides: [
            searchServiceProvider.overrideWithValue(mockSearchService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReaderSearchPanel(
                book: testBook,
                theme: ReaderThemeData.cream,
                onResultSelected: onResultSelected ?? (_, __) {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows hint text', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      expect(find.text('Search in book...'), findsOneWidget);
    });

    testWidgets('close button exists', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows empty prompt initially', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      expect(find.text('Enter a search term to begin.'), findsOneWidget);
    });

    testWidgets('typing triggers debounce and calls search service', (
      tester,
    ) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      verify(() => mockSearchService.searchBook(testBook.id, 'test')).called(1);
    });

    testWidgets('shows loading indicator during search', (tester) async {
      final completer = Completer<List<SearchResult>>();
      when(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete([]);
    });

    testWidgets('shows results when search completes', (tester) async {
      final results = [
        SearchResult(
          chapterIndex: 0,
          snippet: 'found result snippet',
          matchIndex: 0,
        ),
      ];
      when(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).thenAnswer((_) => SynchronousFuture<List<SearchResult>>(results));

      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('found result snippet'), findsOneWidget);
    });

    testWidgets('shows no results message', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'nonexistent');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('No results found.'), findsOneWidget);
    });

    testWidgets('tapping result calls onResultSelected', (tester) async {
      var capturedChapter = -1;
      var capturedQuery = '';
      final results = [
        SearchResult(chapterIndex: 2, snippet: 'matched text', matchIndex: 0),
      ];
      when(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).thenAnswer((_) => SynchronousFuture<List<SearchResult>>(results));

      await tester.pumpWidget(
        buildPanel(
          onResultSelected: (chapter, query) {
            capturedChapter = chapter;
            capturedQuery = query;
          },
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      await tester.tap(find.text('matched text'));
      expect(capturedChapter, 2);
      expect(capturedQuery, 'hello');
    });

    testWidgets('shows chapter index in subtitle', (tester) async {
      final results = [
        SearchResult(chapterIndex: 0, snippet: 'result one', matchIndex: 0),
        SearchResult(chapterIndex: 1, snippet: 'another result', matchIndex: 1),
      ];
      when(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).thenAnswer((_) => SynchronousFuture<List<SearchResult>>(results));

      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('clearing search field shows empty prompt', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Enter a search term to begin.'), findsOneWidget);
    });

    testWidgets('debounce timer fires after 300ms', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 200));
      verifyNever(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      );

      await tester.pump(const Duration(milliseconds: 200));
      verify(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      ).called(1);
    });

    testWidgets('rapid typing only triggers one search', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 't');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'te');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'tes');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      verify(
        () => mockSearchService.searchBook(any<String>(), 'test'),
      ).called(1);
    });

    testWidgets('empty query does not call search service', (tester) async {
      await tester.pumpWidget(buildPanel());
      await tester.pump();

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      verifyNever(
        () => mockSearchService.searchBook(any<String>(), any<String>()),
      );
    });
  });
}
