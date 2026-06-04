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

  static const _labelStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
  );

  @override
  Widget build(BuildContext context) {
    final textStyle = _labelStyle.copyWith(color: themeData.textColor);

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
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (book.format == BookFormat.pdf)
                    _InfoRow(
                      textStyle: textStyle,
                      children: [
                        Flexible(
                          flex: 3,
                          child: _EllipsisLabel(
                            text: book.title,
                            textStyle: textStyle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: _EllipsisLabel(
                            text: _pageCounterLabel(readerState, pdf: true),
                            textStyle: textStyle,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        _ChapterNavButton(
                          enabled: readerState.currentChapterIndex > 0,
                          icon: Icons.chevron_left_rounded,
                          color: themeData.textColor,
                          tooltip: '이전 장',
                          onPressed: onPreviousChapter,
                        ),
                        Expanded(
                          child: _InfoRow(
                            textStyle: textStyle,
                            children: [
                              Flexible(
                                flex: 2,
                                child: _EllipsisLabel(
                                  text: _pageCounterLabel(readerState, pdf: false),
                                  textStyle: textStyle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 4,
                                child: _EllipsisLabel(
                                  text: book.title,
                                  textStyle: textStyle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                flex: 3,
                                child: _EllipsisLabel(
                                  text: _chapterLabel(readerState),
                                  textStyle: textStyle,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ChapterNavButton(
                          enabled: readerState.currentChapterIndex <
                              readerState.chapters.length - 1,
                          icon: Icons.chevron_right_rounded,
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
    final counter =
        '${state.currentPageIndex + 1} / ${state.pages.length}';
    return pdf ? '페이지 $counter' : '${state.currentPageIndex + 1}/${state.pages.length}';
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.textStyle,
    required this.children,
  });

  final TextStyle textStyle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children,
    );
  }
}

class _EllipsisLabel extends StatelessWidget {
  const _EllipsisLabel({
    required this.text,
    required this.textStyle,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle textStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: textStyle,
    );
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
        color: enabled ? color : color.withValues(alpha: 0.25),
        size: 28,
      ),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
