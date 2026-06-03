import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/reader_theme.dart';
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
          _buildColorOption(ref, pageStart, sel, txt, 'FFEB3B', Colors.yellow, state, book, currentChapterIndex),
          _buildColorOption(ref, pageStart, sel, txt, '4CAF50', Colors.green, state, book, currentChapterIndex),
          _buildColorOption(ref, pageStart, sel, txt, 'F44336', Colors.red, state, book, currentChapterIndex),
          _buildColorOption(ref, pageStart, sel, txt, '2196F3', Colors.blue, state, book, currentChapterIndex),
          IconButton(
            icon: Icon(Icons.note_add, size: 18, color: theme.textColor),
            onPressed: () {
              state.hideToolbar();
              _showNoteDialog(context, ref, pageStart, sel, txt, book, currentChapterIndex, theme);
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: col,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
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
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.panelColor,
      title: Text(
        '메모 추가',
        style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: noteController,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          hintText: '메모를 입력하세요...',
          hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.5)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accentColor)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('취소', style: TextStyle(color: theme.secondaryTextColor)),
        ),
        TextButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            final controller = ref.read(readerControllerProvider(book).notifier);
            await controller.addHighlight(
              chapterIndex: currentChapterIndex,
              startOffset: pageStart + sel.start,
              endOffset: pageStart + sel.end,
              text: txt,
              colorHex: 'FFEB3B',
              note: noteController.text,
            );
            navigator.pop();
          },
          child: Text('저장', style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  ).then((_) => noteController.dispose());
}
