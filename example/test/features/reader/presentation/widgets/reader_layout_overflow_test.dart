import 'package:epubx/epubx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_app_bar.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_bottom_bar.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

Book _longTitleBook({BookFormat format = BookFormat.epub}) {
  final ext = switch (format) {
    BookFormat.pdf => 'pdf',
    BookFormat.txt => 'txt',
    BookFormat.epub => 'epub',
  };
  return Book(
    id: 'overflow-test',
    title: '매우 긴 책 제목이 화면 너비를 초과하는 경우에도 오버플로우가 발생하지 않아야 합니다',
    author: '테스트 저자',
    filePath: 'books/test.$ext',
    addedAt: DateTime(2024, 1, 1),
  );
}

List<EpubChapter> _chaptersWithLongTitle() {
  return [
    EpubChapter()
      ..Title =
          '제1장 매우 긴 장 제목이 좁은 화면에서도 하단 바 레이아웃을 깨뜨리지 않아야 합니다',
  ];
}

void main() {
  group('reader chrome overflow', () {
    testWidgets('ReaderAppBar truncates long title on narrow width', (tester) async {
      final book = _longTitleBook();
      final state = ReaderState(
        book: book,
        pages: const ['page'],
        isLoading: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)),
            child: Scaffold(
              body: Stack(
                children: [
                  ReaderAppBar(
                    showUi: true,
                    book: book,
                    readerState: state,
                    themeData: ReaderThemeData.cream,
                    isTtsPlaying: false,
                    onBack: () {},
                    onTtsPressed: () {},
                    onSettingsPressed: () {},
                    onSearchPressed: () {},
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

    testWidgets('ReaderBottomBar fits page, title, and chapter on narrow width',
        (tester) async {
      final book = _longTitleBook();
      final state = ReaderState(
        book: book,
        pages: List.filled(500, 'page'),
        chapters: _chaptersWithLongTitle(),
        isLoading: false,
        currentChapterIndex: 0,
        currentPageIndex: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 640)),
            child: Scaffold(
              body: Stack(
                children: [
                  ReaderBottomBar(
                    showUi: true,
                    book: book,
                    readerState: state,
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
      expect(find.textContaining(book.title), findsOneWidget);
    });

    testWidgets('ReaderBottomBar fits chapter nav with many chapters', (tester) async {
      final book = _longTitleBook();
      final state = ReaderState(
        book: book,
        pages: List.filled(500, 'page'),
        chapters: List.generate(
          50,
          (i) => EpubChapter()..Title = 'Chapter $i',
        ),
        isLoading: false,
        currentChapterIndex: 48,
        currentPageIndex: 12,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(280, 640)),
            child: Scaffold(
              body: Stack(
                children: [
                  ReaderBottomBar(
                    showUi: true,
                    book: book,
                    readerState: state,
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

    testWidgets('ReaderBottomBar fits PDF title and page counter on narrow width',
        (tester) async {
      final book = _longTitleBook(format: BookFormat.pdf);
      final state = ReaderState(
        book: book,
        pages: List.filled(9999, 'page'),
        isLoading: false,
        currentPageIndex: 1234,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(280, 640)),
            child: Scaffold(
              body: Stack(
                children: [
                  ReaderBottomBar(
                    showUi: true,
                    book: book,
                    readerState: state,
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
      expect(find.textContaining('페이지'), findsOneWidget);
    });
  });
}
