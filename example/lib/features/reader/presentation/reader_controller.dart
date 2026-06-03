import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../bookshelf/domain/book.dart';
import '../../epub/data/epub_service.dart';
import '../domain/reader_settings.dart';
import '../domain/reading_progress.dart';
import '../../../shared/theme/app_theme_controller.dart';
import '../../../shared/theme/reader_theme.dart';
import '../../../shared/theme/reader_typography.dart';
import '../application/epub_paging_calculator.dart';
import '../application/txt_service.dart';
import '../application/pdf_service.dart';
import 'reader_state.dart';
import 'package:epubx/epubx.dart';
import 'package:drift/drift.dart';
import '../../bookshelf/data/book_repository_provider.dart';
import '../../bookshelf/data/database.dart';

part 'reader_controller.g.dart';

@riverpod
class ReaderController extends _$ReaderController {
  final EpubService _epubService = EpubService();
  static const _settingsKey = 'reader_settings';
  static const _progressKeyPrefix = 'reader_progress_';

  @override
  ReaderState build(Book book) {
    ref.listen(appThemeControllerProvider, (previous, next) {
      if (previous != next && state.viewportWidth > 0 && state.viewportHeight > 0) {
        _recalculatePages();
      }
    });

    // Asynchronously initialize book content
    _init(book);
    
    // Register general dispose hooks if needed
    ref.onDispose(() {
      PdfService.closeDocument(book.filePath);
    });

    return ReaderState(book: book);
  }

  Future<void> _init(Book book) async {
    try {
      final format = book.format;
      final settings = await _loadSettings();
      final progress = await _loadProgress(book.id);
      final highlights = await ref.read(appDatabaseProvider).getHighlightsForBook(book.id);

      if (format == BookFormat.epub) {
        final epubBook = await _epubService.loadBook(book.filePath);
        final chapters = _epubService.flattenChapters(epubBook);
        final chapterIndex = progress.chapterIndex < chapters.length ? progress.chapterIndex : 0;

        state = state.copyWith(
          epubBook: epubBook,
          chapters: chapters,
          currentChapterIndex: chapterIndex,
          currentPageIndex: progress.pageIndex,
          highlights: highlights,
          settings: settings,
          isLoading: false,
        );

        if (state.viewportWidth > 0 && state.viewportHeight > 0) {
          _recalculatePages();
        }
      } else if (format == BookFormat.txt) {
        final txtService = TxtService();
        final chapters = await txtService.parseChapters(book.filePath);
        final chapterIndex = progress.chapterIndex < chapters.length ? progress.chapterIndex : 0;

        state = state.copyWith(
          chapters: chapters,
          currentChapterIndex: chapterIndex,
          currentPageIndex: progress.pageIndex,
          highlights: highlights,
          settings: settings,
          isLoading: false,
        );

        if (state.viewportWidth > 0 && state.viewportHeight > 0) {
          _recalculatePages();
        }
      } else if (format == BookFormat.pdf) {
        final pdfService = PdfService();
        final pageCount = await pdfService.getPagesCount(book.filePath);
        final isLandscape = await PdfService.isLandscapeDocument(book.filePath);

        // Keep PDF as 1 single virtual chapter representing the whole book
        final mockChapter = EpubChapter()
          ..Title = '전체 페이지'
          ..HtmlContent = '';

        final pages = List.generate(pageCount, (index) => '$index');
        final pageIndex = progress.pageIndex < pageCount ? progress.pageIndex : 0;

        state = state.copyWith(
          chapters: [mockChapter],
          currentChapterIndex: 0,
          pages: pages,
          currentPageIndex: pageIndex,
          highlights: highlights,
          settings: settings,
          isLoading: false,
          isPdfLandscape: isLandscape,
        );
      }
    } catch (e) {
      debugPrint('Error initializing e-book reader: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void setViewportSize(double width, double height) {
    if (state.viewportWidth == width && state.viewportHeight == height) {
      return;
    }
    state = state.copyWith(
      viewportWidth: width,
      viewportHeight: height,
    );
    _recalculatePages();
  }

  void _recalculatePages() {
    final format = book.format;
    if (format == BookFormat.pdf) return; // PDF pages are fixed-layout

    if (state.chapters.isEmpty) return;

    final currentChapter = state.chapters[state.currentChapterIndex];
    final text = _epubService.getChapterText(currentChapter);

    final themeData = ReaderThemeData.get(ref.read(appThemeControllerProvider));
    final isDouble = state.isDoublePage;
    final spacing = isDouble ? 56.0 : 0.0;
    final activeWidth = isDouble ? (state.viewportWidth - spacing) / 2 : state.viewportWidth;

    final pages = EpubPagingCalculator.splitIntoPages(
      text: text,
      viewportWidth: activeWidth,
      viewportHeight: state.viewportHeight,
      fontSize: state.settings.fontSize,
      lineHeight: state.settings.lineHeight,
      baseStyle: ReaderTypography.getBookStyle(
        fontSize: state.settings.fontSize,
        color: themeData.textColor,
      ),
    );

    int pageIndex = state.currentPageIndex;
    // Align starting index to the left page of a spread in double-page mode
    if (isDouble && !state.isPdfLandscape && pageIndex > 0 && pageIndex % 2 != 0) {
      pageIndex--;
    }
    if (pageIndex >= pages.length) {
      pageIndex = pages.isEmpty ? 0 : pages.length - 1;
      if (isDouble && !state.isPdfLandscape && pageIndex > 0 && pageIndex % 2 != 0) {
        pageIndex--;
      }
    }

    state = state.copyWith(
      pages: pages,
      currentPageIndex: pageIndex,
    );
    
    _saveProgress();
  }

  Future<void> updateFontSize(double delta) async {
    final newSize = (state.settings.fontSize + delta).clamp(12.0, 30.0);
    if (newSize == state.settings.fontSize) return;

    state = state.copyWith(
      settings: state.settings.copyWith(fontSize: newSize),
    );
    _recalculatePages();
    await _saveSettings();
  }

  Future<void> toggleHaptics(bool enabled) async {
    state = state.copyWith(
      settings: state.settings.copyWith(enableHaptics: enabled),
    );
    await _saveSettings();
  }

  Future<void> toggleSound(bool enabled) async {
    state = state.copyWith(
      settings: state.settings.copyWith(enableSound: enabled),
    );
    await _saveSettings();
  }

  void goToPageIndex(int index) {
    if (index < 0 || index >= state.pages.length) return;
    state = state.copyWith(currentPageIndex: index);
    _saveProgress();
  }

  void jumpToChapterWithQuery(int chapterIndex, String query) {
    if (chapterIndex < 0 || chapterIndex >= state.chapters.length) return;
    
    state = state.copyWith(
      currentChapterIndex: chapterIndex,
      currentPageIndex: 0,
    );
    
    _recalculatePages();
    
    // Find the exact page index containing the matching search term
    for (int i = 0; i < state.pages.length; i++) {
      if (state.pages[i].toLowerCase().contains(query.toLowerCase())) {
        state = state.copyWith(currentPageIndex: i);
        break;
      }
    }
    _saveProgress();
  }

  void nextPage() {
    final step = (state.isDoublePage && !state.isPdfLandscape) ? 2 : 1;
    if (state.currentPageIndex + step < state.pages.length) {
      goToPageIndex(state.currentPageIndex + step);
    } else if (state.currentChapterIndex < state.chapters.length - 1) {
      state = state.copyWith(
        currentChapterIndex: state.currentChapterIndex + 1,
        currentPageIndex: 0,
      );
      _recalculatePages();
    }
  }

  void previousPage() {
    final step = (state.isDoublePage && !state.isPdfLandscape) ? 2 : 1;
    if (state.currentPageIndex >= step) {
      goToPageIndex(state.currentPageIndex - step);
    } else if (state.currentChapterIndex > 0) {
      final prevChapterIndex = state.currentChapterIndex - 1;
      final currentChapter = state.chapters[prevChapterIndex];
      final text = _epubService.getChapterText(currentChapter);
      
      final themeData = ReaderThemeData.get(ref.read(appThemeControllerProvider));
      final isDouble = state.isDoublePage;
      final spacing = isDouble ? 56.0 : 0.0;
      final activeWidth = isDouble ? (state.viewportWidth - spacing) / 2 : state.viewportWidth;
      
      final pages = EpubPagingCalculator.splitIntoPages(
        text: text,
        viewportWidth: activeWidth,
        viewportHeight: state.viewportHeight,
        fontSize: state.settings.fontSize,
        lineHeight: state.settings.lineHeight,
        baseStyle: ReaderTypography.getBookStyle(
          fontSize: state.settings.fontSize,
          color: themeData.textColor,
        ),
      );
      
      int targetPageIndex = pages.isEmpty ? 0 : pages.length - 1;
      if (isDouble && !state.isPdfLandscape && targetPageIndex > 0 && targetPageIndex % 2 != 0) {
        targetPageIndex--;
      }
      
      state = state.copyWith(
        currentChapterIndex: prevChapterIndex,
        pages: pages,
        currentPageIndex: targetPageIndex,
      );
      _saveProgress();
    }
  }

  Future<ReaderSettings> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_settingsKey);
    if (jsonStr != null) {
      try {
        return ReaderSettings.fromJson(json.decode(jsonStr));
      } catch (_) {}
    }
    return const ReaderSettings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, json.encode(state.settings.toJson()));
  }

  Future<ReadingProgress> _loadProgress(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_progressKeyPrefix$bookId');
    if (jsonStr != null) {
      try {
        return ReadingProgress.fromJson(json.decode(jsonStr));
      } catch (_) {}
    }
    return ReadingProgress(
      bookId: bookId,
      lastReadAt: DateTime.now(),
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progress = ReadingProgress(
      bookId: state.book.id,
      chapterIndex: state.currentChapterIndex,
      pageIndex: state.currentPageIndex,
      lastReadAt: DateTime.now(),
    );
    await prefs.setString(
      '$_progressKeyPrefix${state.book.id}',
      json.encode(progress.toJson()),
    );
  }

  Future<void> addHighlight({
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required String text,
    required String colorHex,
    String? note,
  }) async {
    await ref.read(appDatabaseProvider).insertHighlight(
      HighlightsCompanion(
        bookId: Value(book.id),
        chapterIndex: Value(chapterIndex),
        startOffset: Value(startOffset),
        endOffset: Value(endOffset),
        selectedText: Value(text),
        highlightColor: Value(colorHex),
        note: Value(note),
      ),
    );

    // Refresh highlights in state
    final highlights = await ref.read(appDatabaseProvider).getHighlightsForBook(book.id);
    state = state.copyWith(highlights: highlights);
  }

  Future<void> removeHighlight(int id) async {
    await ref.read(appDatabaseProvider).deleteHighlight(id);

    // Refresh highlights in state
    final highlights = await ref.read(appDatabaseProvider).getHighlightsForBook(book.id);
    state = state.copyWith(highlights: highlights);
  }
}
