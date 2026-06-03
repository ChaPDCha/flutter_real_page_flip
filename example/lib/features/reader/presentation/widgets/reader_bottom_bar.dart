import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../bookshelf/domain/book.dart';
import '../reader_state.dart';

class ReaderBottomBar extends StatelessWidget {
  final bool showUi;
  final Book book;
  final ReaderState readerState;
  final ReaderThemeData themeData;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;

  const ReaderBottomBar({
    super.key,
    required this.showUi,
    required this.book,
    required this.readerState,
    required this.themeData,
    required this.onPreviousChapter,
    required this.onNextChapter,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      bottom: showUi ? 0 : -80 - MediaQuery.of(context).padding.bottom,
      left: 0,
      right: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showUi ? 1.0 : 0.0,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              color: themeData.panelColor.withValues(alpha: 0.8),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 8,
                top: 8,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: book.format == BookFormat.pdf
                        ? [
                            const SizedBox.shrink(),
                            Text(
                              '페이지 ${readerState.currentPageIndex + 1} / ${readerState.pages.length}',
                              style: TextStyle(
                                fontSize: 13,
                                color: themeData.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox.shrink(),
                          ]
                        : [
                            IconButton(
                              onPressed: readerState.currentChapterIndex > 0
                                  ? onPreviousChapter
                                  : null,
                              icon: Icon(
                                Icons.chevron_left_rounded,
                                color: readerState.currentChapterIndex > 0
                                    ? themeData.textColor
                                    : themeData.textColor.withValues(alpha: 0.25),
                                size: 28,
                              ),
                              tooltip: '이전 장',
                            ),
                            Text(
                              readerState.chapters.isNotEmpty
                                  ? '장 ${readerState.currentChapterIndex + 1} / ${readerState.chapters.length}'
                                  : '',
                              style: TextStyle(
                                fontSize: 13,
                                color: themeData.textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            IconButton(
                              onPressed: readerState.currentChapterIndex < readerState.chapters.length - 1
                                  ? onNextChapter
                                  : null,
                              icon: Icon(
                                Icons.chevron_right_rounded,
                                color: readerState.currentChapterIndex < readerState.chapters.length - 1
                                    ? themeData.textColor
                                    : themeData.textColor.withValues(alpha: 0.25),
                                size: 28,
                              ),
                              tooltip: '다음 장',
                            ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
