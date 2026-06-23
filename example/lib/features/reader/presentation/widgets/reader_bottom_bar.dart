import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
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
    final textStyle = ReaderTypography.getUiStyle(
      color: themeData.textColor,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    final pageStyle = ReaderTypography.getGeometricStyle(
      color: themeData.textColor,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

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
            filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: themeData.panelColor.withValues(alpha: 0.75),
                border: Border(
                  top: BorderSide(
                    color: themeData.textColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (book.format == BookFormat.pdf)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _pageCounterLabel(readerState, pdf: true),
                          style: pageStyle,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _ChapterNavButton(
                          enabled: readerState.currentChapterIndex > 0,
                          icon: Icons.keyboard_arrow_left_rounded,
                          color: themeData.textColor,
                          tooltip: '이전 장',
                          onPressed: onPreviousChapter,
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                flex: 2,
                                child: Text(
                                  _pageCounterLabel(readerState, pdf: false),
                                  style: pageStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: textStyle.copyWith(
                                    color: themeData.textColor.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                flex: 3,
                                child: Text(
                                  _chapterLabel(readerState),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: textStyle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ChapterNavButton(
                          enabled:
                              readerState.currentChapterIndex <
                              readerState.chapters.length - 1,
                          icon: Icons.keyboard_arrow_right_rounded,
                          color: themeData.textColor,
                          tooltip: '다음 장',
                          onPressed: onNextChapter,
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

  static String _pageCounterLabel(ReaderState state, {required bool pdf}) {
    if (state.pages.isEmpty) return '';
    final counter = '${state.currentPageIndex + 1} / ${state.pages.length}';
    return pdf
        ? '페이지 $counter'
        : '${state.currentPageIndex + 1}/${state.pages.length}';
  }

  static String _chapterLabel(ReaderState state) {
    if (state.chapters.isEmpty) return '';
    final chapter = state.chapters[state.currentChapterIndex];
    final title = chapter.Title?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return '장 ${state.currentChapterIndex + 1}/${state.chapters.length}';
  }
}

class _ChapterNavButton extends StatelessWidget {
  const _ChapterNavButton({
    required this.enabled,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final bool enabled;
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(
        icon,
        color: enabled ? color : color.withValues(alpha: 0.2),
        size: 26,
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
