import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_bottom_bar.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

Widget _wrapWithProviders(Widget child) {
  return TranslationProvider(child: MaterialApp(home: child));
}

void main() {
  group('ReaderBottomBar', () {
    final testBook = Book(
      id: 'test-book',
      title: 'Bottom Bar Book',
      author: 'Test Author',
      filePath: 'test/book.epub',
      addedAt: DateTime(2024, 1, 1),
    );

    final pdfBook = Book(
      id: 'test-pdf',
      title: 'PDF Book Title',
      author: 'Test Author',
      filePath: 'test/book.pdf',
      addedAt: DateTime(2024, 1, 1),
    );

    final chapters = [
      EpubChapter()..Title = 'Chapter 1',
      EpubChapter()..Title = 'Chapter 2',
      EpubChapter()..Title = 'Chapter 3',
    ];

    final chaptersWithEmptyTitle = [
      EpubChapter()..Title = '',
      EpubChapter()..Title = 'Chapter 2',
    ];

    Finder findIconButtonByIcon(IconData icon) {
      return find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(IconButton),
      );
    }

    ReaderState defaultState({
      int chapterIndex = 1,
      int pageIndex = 50,
      int pageCount = 100,
      List<EpubChapter>? chaptersList,
      Book? book,
    }) {
      return ReaderState(
        book: book ?? testBook,
        chapters: chaptersList ?? chapters,
        pages: List.filled(pageCount, 'page'),
        currentChapterIndex: chapterIndex,
        currentPageIndex: pageIndex,
        isLoading: false,
      );
    }

    Widget buildBottomBar({
      bool showUi = true,
      Book? book,
      ReaderState? state,
      VoidCallback? onPreviousChapter,
      VoidCallback? onNextChapter,
    }) {
      return _wrapWithProviders(
        Scaffold(
          body: Stack(
            children: [
              ReaderBottomBar(
                showUi: showUi,
                book: book ?? testBook,
                readerState: state ?? defaultState(),
                themeData: ReaderThemeData.cream,
                onPreviousChapter: onPreviousChapter ?? () {},
                onNextChapter: onNextChapter ?? () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders book title', (tester) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      expect(find.text('Bottom Bar Book'), findsOneWidget);
    });

    testWidgets('page counter format for non-PDF', (tester) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      // currentPageIndex=50, pages.length=100 => "51/100"
      expect(find.text('51/100'), findsOneWidget);
    });

    testWidgets('page counter format for PDF', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(
          book: pdfBook,
          state: defaultState(book: pdfBook, pageIndex: 9, pageCount: 200),
        ),
      );
      await tester.pump();

      // PDF: "Page 10 / 200"
      expect(find.textContaining('10 / 200'), findsOneWidget);
    });

    testWidgets('previous chapter enabled when not at first chapter', (
      tester,
    ) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      final prevButton = tester.widget<IconButton>(
        findIconButtonByIcon(Icons.keyboard_arrow_left_rounded),
      );
      expect(prevButton.onPressed, isNotNull);
    });

    testWidgets('previous chapter disabled at first chapter', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(state: defaultState(chapterIndex: 0)),
      );
      await tester.pump();

      final prevButton = tester.widget<IconButton>(
        findIconButtonByIcon(Icons.keyboard_arrow_left_rounded),
      );
      expect(prevButton.onPressed, isNull);
    });

    testWidgets('next chapter enabled when not at last chapter', (
      tester,
    ) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      final nextButton = tester.widget<IconButton>(
        findIconButtonByIcon(Icons.keyboard_arrow_right_rounded),
      );
      expect(nextButton.onPressed, isNotNull);
    });

    testWidgets('next chapter disabled at last chapter', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(state: defaultState(chapterIndex: 2)),
      );
      await tester.pump();

      final nextButton = tester.widget<IconButton>(
        findIconButtonByIcon(Icons.keyboard_arrow_right_rounded),
      );
      expect(nextButton.onPressed, isNull);
    });

    testWidgets('tapping previous chapter calls callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildBottomBar(onPreviousChapter: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(findIconButtonByIcon(Icons.keyboard_arrow_left_rounded));
      expect(tapped, isTrue);
    });

    testWidgets('tapping next chapter calls callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildBottomBar(onNextChapter: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(
        findIconButtonByIcon(Icons.keyboard_arrow_right_rounded),
      );
      expect(tapped, isTrue);
    });

    testWidgets('chapter label shows chapter title', (tester) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      // currentChapterIndex=1, chapters[1].Title = 'Chapter 2'
      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('chapter label fallback when title is empty', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(
          state: defaultState(
            chapterIndex: 0,
            chaptersList: chaptersWithEmptyTitle,
          ),
        ),
      );
      await tester.pump();

      // Empty title -> fallback format "#1/2"
      expect(find.text('#1/2'), findsOneWidget);
    });

    testWidgets('chapter label fallback when no chapters', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(state: defaultState(chaptersList: [])),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('empty pages renders without error', (tester) async {
      await tester.pumpWidget(
        buildBottomBar(
          state: ReaderState(
            book: testBook,
            chapters: chapters,
            currentChapterIndex: 0,
            currentPageIndex: 0,
            isLoading: false,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('previous chapter icon is keyboard_arrow_left_rounded', (
      tester,
    ) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsOneWidget);
    });

    testWidgets('next chapter icon is keyboard_arrow_right_rounded', (
      tester,
    ) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsOneWidget);
    });

    testWidgets('BackdropFilter is present', (tester) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('AnimatedPositioned and AnimatedOpacity are used', (
      tester,
    ) async {
      await tester.pumpWidget(buildBottomBar());
      await tester.pump();

      expect(find.byType(AnimatedPositioned), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('showUi=false renders without error', (tester) async {
      await tester.pumpWidget(buildBottomBar(showUi: false));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error on narrow width', (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          MediaQuery(
            data: const MediaQueryData(size: Size(280, 640)),
            child: Scaffold(
              body: Stack(
                children: [
                  ReaderBottomBar(
                    showUi: true,
                    book: testBook,
                    readerState: defaultState(),
                    themeData: ReaderThemeData.cream,
                    onPreviousChapter: () {},
                    onNextChapter: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
