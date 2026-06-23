import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../epub/data/epub_service.dart';
import '../../../tts/application/supertonic_tts_provider.dart';
import '../../../tts/application/supertonic_tts_service.dart';
import '../reader_state.dart';
import 'page_spans_helper.dart';
import 'reader_selection_toolbar.dart';
import 'text_position_helper.dart';

class ReflowablePageContent extends ConsumerWidget {
  final ReaderState state;
  final ReaderThemeData theme;
  final int index;

  const ReflowablePageContent({
    super.key,
    required this.state,
    required this.theme,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.pages.isEmpty || index >= state.pages.length) {
      return Container(color: theme.backgroundColor);
    }

    final pageText = state.pages[index];
    final chapterTitle = state.chapters.isNotEmpty
        ? state.chapters[state.currentChapterIndex].Title ??
              'Chapter ${state.currentChapterIndex + 1}'
        : '';

    // Calculate absolute page character offsets in the chapter
    final epubService = EpubService();
    final chapterText = epubService.getChapterText(
      state.chapters[state.currentChapterIndex],
    );
    int pageStartOffset = 0;
    int previousEnd = 0;
    for (int i = 0; i < index; i++) {
      final pText = state.pages[i];
      final found = chapterText.indexOf(pText, previousEnd);
      if (found != -1) {
        previousEnd = found + pText.length;
      }
    }
    final foundIndex = chapterText.indexOf(pageText, previousEnd);
    pageStartOffset = foundIndex != -1 ? foundIndex : previousEnd;
    final pageEndOffset = pageStartOffset + pageText.length;

    // Filter and sort active highlights for the current page
    final pageHighlights = state.highlights.where((hl) {
      return hl.chapterIndex == state.currentChapterIndex &&
          hl.startOffset < pageEndOffset &&
          hl.endOffset > pageStartOffset;
    }).toList();
    pageHighlights.sort((a, b) => a.startOffset.compareTo(b.startOffset));

    final baseStyle = ReaderTypography.getBookStyle(
      fontSize: state.settings.fontSize,
      color: theme.textColor,
      lineHeight: state.settings.lineHeight,
      fontFamily: state.settings.fontFamily,
    );

    // Watch TTS state
    final ttsService = ref.watch(supertonicTtsProvider);
    final activeTtsPageIndex = ref.watch(activeTtsPageIndexProvider);
    final activeTtsStartOffset = ref.watch(activeTtsStartOffsetProvider);

    return StreamBuilder<TtsWordHighlight?>(
      stream: ttsService.highlightStream,
      builder: (context, snapshot) {
        final ttsHl = snapshot.data;
        final ttsStartInPage = activeTtsPageIndex == index && ttsHl != null
            ? activeTtsStartOffset + ttsHl.startOffset
            : -1;
        final ttsEndInPage = activeTtsPageIndex == index && ttsHl != null
            ? activeTtsStartOffset + ttsHl.endOffset
            : -1;

        final spans = buildPageSpans(
          pageText: pageText,
          pageHighlights: pageHighlights,
          pageStartOffset: pageStartOffset,
          ttsStartInPage: ttsStartInPage,
          ttsEndInPage: ttsEndInPage,
          baseStyle: baseStyle,
        );

        return Container(
          color: theme.backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ReaderTypography.getUiStyle(
                  fontSize: 11,
                  color: theme.secondaryTextColor.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onDoubleTapDown: (details) {
                        _handleDoubleTap(
                          context,
                          ref,
                          details.localPosition,
                          constraints,
                        );
                      },
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SelectableText.rich(
                          TextSpan(children: spans),
                          contextMenuBuilder: (context, editableTextState) {
                            final selection =
                                editableTextState.textEditingValue.selection;
                            if (selection.isCollapsed) {
                              return const SizedBox.shrink();
                            }
                            final selectedText = editableTextState
                                .textEditingValue
                                .text
                                .substring(selection.start, selection.end);
                            return buildSelectionToolbar(
                              context: context,
                              ref: ref,
                              state: editableTextState,
                              pageStart: pageStartOffset,
                              sel: selection,
                              txt: selectedText,
                              book: state.book,
                              currentChapterIndex: state.currentChapterIndex,
                              theme: theme,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${index + 1} / ${state.pages.length}',
                    style: ReaderTypography.getGeometricStyle(
                      fontSize: 10,
                      color: theme.secondaryTextColor.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: ReaderTypography.getUiStyle(
                        fontSize: 10,
                        color: theme.secondaryTextColor.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDoubleTap(
    BuildContext context,
    WidgetRef ref,
    Offset localOffset,
    BoxConstraints constraints,
  ) async {
    final pageText = state.pages[index];
    final baseStyle = ReaderTypography.getBookStyle(
      fontSize: state.settings.fontSize,
      color: theme.textColor,
      lineHeight: state.settings.lineHeight,
    );

    final charOffset = getCharOffsetForPosition(
      localOffset,
      pageText,
      baseStyle,
      constraints.maxWidth,
    );
    if (charOffset < 0 || charOffset >= pageText.length) return;

    final entry = getSentenceAtOffset(pageText, charOffset);
    final sentenceStartOffset = entry.key;
    final sentenceText = entry.value;

    if (sentenceText.isEmpty) return;

    await ref.read(supertonicTtsProvider).stop();

    ref.read(activeTtsPageIndexProvider.notifier).set(index);
    ref.read(activeTtsStartOffsetProvider.notifier).set(sentenceStartOffset);

    final remainingText = pageText.substring(sentenceStartOffset);
    await ref.read(supertonicTtsProvider).speak(remainingText);
  }
}
