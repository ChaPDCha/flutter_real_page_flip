import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/reader_theme.dart';
import '../../../../shared/theme/reader_theme_dialogs.dart';
import '../../../../shared/theme/reader_typography.dart';
import '../../../bookshelf/domain/book.dart';
import '../reader_controller.dart';

Widget buildSelectionToolbar({
  required BuildContext context,
  required WidgetRef ref,
  required EditableTextState state,
  required int pageStart,
  required TextSelection sel,
  required String txt,
  required Book book,
  required int currentChapterIndex,
  required ReaderThemeData theme,
}) {
  final List<Widget> children = [];

  // 1. Highlight Colors & Notes Action Row
  children.add(
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildColorOption(
            ref,
            pageStart,
            sel,
            txt,
            'FFD48F',
            const Color(0xFFDDB032),
            state,
            book,
            currentChapterIndex,
            theme,
          ),
          _buildColorOption(
            ref,
            pageStart,
            sel,
            txt,
            'A2D497',
            const Color(0xFF76A665),
            state,
            book,
            currentChapterIndex,
            theme,
          ),
          _buildColorOption(
            ref,
            pageStart,
            sel,
            txt,
            'F2A6A6',
            const Color(0xFFC05D5D),
            state,
            book,
            currentChapterIndex,
            theme,
          ),
          _buildColorOption(
            ref,
            pageStart,
            sel,
            txt,
            'A6C7F2',
            const Color(0xFF5D80A6),
            state,
            book,
            currentChapterIndex,
            theme,
          ),
          IconButton(
            icon: Icon(
              Icons.note_add_outlined,
              size: 18,
              color: theme.textColor,
            ),
            onPressed: () {
              state.hideToolbar();
              _showNoteDialog(
                context,
                ref,
                pageStart,
                sel,
                txt,
                book,
                currentChapterIndex,
                theme,
              );
            },
          ),
        ],
      ),
    ),
  );

  // 2. Default Platform Text Selection Options (Copy, Share, etc.)
  children.addAll(
    AdaptiveTextSelectionToolbar.getAdaptiveButtons(
      context,
      state.contextMenuButtonItems,
    ),
  );

  return AdaptiveTextSelectionToolbar(
    anchors: state.contextMenuAnchors,
    children: children,
  );
}

Widget _buildColorOption(
  WidgetRef ref,
  int pageStart,
  TextSelection sel,
  String txt,
  String hex,
  Color col,
  EditableTextState state,
  Book book,
  int currentChapterIndex,
  ReaderThemeData theme,
) {
  return GestureDetector(
    onTap: () async {
      state.hideToolbar();
      final controller = ref.read(readerControllerProvider(book).notifier);
      await controller.addHighlight(
        chapterIndex: currentChapterIndex,
        startOffset: pageStart + sel.start,
        endOffset: pageStart + sel.end,
        text: txt,
        colorHex: hex,
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: col,
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.textColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 3,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
    ),
  );
}

void _showNoteDialog(
  BuildContext context,
  WidgetRef ref,
  int pageStart,
  TextSelection sel,
  String txt,
  Book book,
  int currentChapterIndex,
  ReaderThemeData theme,
) {
  final noteController = TextEditingController();
  showThemedDialog(
    context: context,
    theme: theme,
    builder: (context) => AlertDialog(
      backgroundColor: theme.panelColor,
      title: Text(
        '메모 추가',
        style: ReaderTypography.getUiStyle(
          color: theme.textColor,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: TextField(
        controller: noteController,
        style: ReaderTypography.getUiStyle(color: theme.textColor),
        cursorColor: theme.accentColor,
        decoration: InputDecoration(
          hintText: '메모를 입력하세요...',
          hintStyle: ReaderTypography.getUiStyle(
            color: theme.secondaryTextColor.withValues(alpha: 0.4),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.dividerColor),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: theme.accentColor),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: ReaderTypography.getUiStyle(color: theme.secondaryTextColor),
          ),
        ),
        TextButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final controller = ref.read(
              readerControllerProvider(book).notifier,
            );
            await controller.addHighlight(
              chapterIndex: currentChapterIndex,
              startOffset: pageStart + sel.start,
              endOffset: pageStart + sel.end,
              text: txt,
              colorHex: 'FFD48F',
              note: noteController.text,
            );
            navigator.pop();
          },
          child: Text(
            '저장',
            style: ReaderTypography.getUiStyle(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ).then((_) => noteController.dispose());
}
