import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import '../../../shared/theme/app_theme_controller.dart';
import '../../../shared/theme/reader_theme.dart';
import '../../../shared/theme/reader_theme_dialogs.dart';
import 'bookshelf_controller.dart';
import '../domain/book.dart';
import '../../reader/presentation/book_reader_screen.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  static bool _filePickerInProgress = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfState = ref.watch(bookshelfControllerProvider);
    final themeData = ReaderThemeData.get(ref.watch(appThemeControllerProvider));

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Realbook 서재',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'serif',
            color: themeData.textColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: themeData.panelColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: themeData.textColor),
            tooltip: '책 추가 (EPUB, TXT, PDF)',
            onPressed: () => _pickAndImportEpub(context, ref),
          ),
        ],
      ),
      body: bookshelfState.when(
        data: (books) => books.isEmpty
            ? _buildEmptyState(context, ref, themeData)
            : _buildBookGrid(context, ref, books, themeData),
        loading: () => Skeletonizer(
          enabled: true,
          child: _buildSkeletonGrid(themeData),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: ReaderThemeData.errorColor),
              const SizedBox(height: 16),
              Text(
                '오류가 발생했습니다:\n$err',
                textAlign: TextAlign.center,
                style: TextStyle(color: themeData.textColor),
              ),
              const SizedBox(height: 16),
              ShadButton(
                onPressed: () => ref.refresh(bookshelfControllerProvider),
                backgroundColor: themeData.accentColor,
                child: Text('다시 시도', style: TextStyle(color: themeData.buttonForegroundColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid(ReaderThemeData themeData) {
    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 18,
        mainAxisSpacing: 24,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Card(
                color: themeData.panelColor,
                elevation: 2,
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 14,
              width: double.infinity,
              color: themeData.dividerColor,
            ),
            const SizedBox(height: 6),
            Container(
              height: 10,
              width: 60,
              color: themeData.dividerColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    ReaderThemeData themeData,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: themeData.secondaryTextColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              '서재가 비어 있습니다',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: themeData.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '상단의 + 버튼을 누르거나 아래 버튼을 눌러 소장하고 계신\n전자책 파일(EPUB, TXT, PDF)을 서재에 추가해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: themeData.secondaryTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ShadButton(
              onPressed: () => _pickAndImportEpub(context, ref),
              backgroundColor: themeData.accentColor,
              foregroundColor: themeData.buttonForegroundColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_open, size: 16, color: themeData.buttonForegroundColor),
                  const SizedBox(width: 8),
                  Text('책 파일 가져오기', style: TextStyle(color: themeData.buttonForegroundColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookGrid(
    BuildContext context,
    WidgetRef ref,
    List<Book> books,
    ReaderThemeData themeData,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(24.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 18,
        mainAxisSpacing: 24,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _buildBookCard(context, ref, book, themeData);
      },
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    WidgetRef ref,
    Book book,
    ReaderThemeData themeData,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BookReaderScreen(book: book),
          ),
        );
      },
      onLongPress: () => _showBookActionsSheet(context, ref, book, themeData),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: themeData.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: book.coverImagePath != null
                  ? Image.file(
                      File(book.coverImagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : _buildDefaultCover(book, themeData),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: themeData.textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: themeData.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(Book book, ReaderThemeData themeData) {
    return Container(
      decoration: BoxDecoration(
        color: themeData.coverBackgroundColor,
        border: Border.all(color: themeData.coverBorderColor, width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: themeData.secondaryTextColor.withValues(alpha: 0.5),
            size: 16,
          ),
          Expanded(
            child: Center(
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: themeData.coverTitleColor,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: themeData.secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndImportEpub(BuildContext context, WidgetRef ref) async {
    if (_filePickerInProgress) return;
    _filePickerInProgress = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub', 'txt', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await ref.read(bookshelfControllerProvider.notifier).importBook(file);
      }
    } on PlatformException catch (e) {
      if (e.code == 'already_active') return;
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('가져오기 실패'),
            description: Text('책 가져오기에 실패했습니다: ${e.message ?? e.code}'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('가져오기 실패'),
            description: Text('책 가져오기에 실패했습니다: $e'),
          ),
        );
      }
    } finally {
      _filePickerInProgress = false;
    }
  }

  void _showBookActionsSheet(
    BuildContext context,
    WidgetRef ref,
    Book book,
    ReaderThemeData themeData,
  ) {
    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: themeData.panelColor,
          topBarTitle: Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'serif',
              color: themeData.textColor,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '저자: ${book.author}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: themeData.secondaryTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ShadButton(
                  onPressed: () {
                    Navigator.of(modalContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BookReaderScreen(book: book),
                      ),
                    );
                  },
                  backgroundColor: themeData.accentColor,
                  foregroundColor: themeData.buttonForegroundColor,
                  child: Text('책 읽기', style: TextStyle(color: themeData.buttonForegroundColor)),
                ),
                const SizedBox(height: 12),
                ShadButton.destructive(
                  onPressed: () async {
                    final confirm = await showThemedAdaptiveDialog<bool>(
                      context: modalContext,
                      theme: themeData,
                      builder: (dialogContext) => AlertDialog.adaptive(
                        backgroundColor: themeData.panelColor,
                        title: Text(
                          '책 삭제',
                          style: TextStyle(color: themeData.textColor),
                        ),
                        content: Text(
                          '"${book.title}" 책을 서재에서 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
                          style: TextStyle(color: themeData.secondaryTextColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
                            child: Text(
                              '취소',
                              style: TextStyle(color: themeData.secondaryTextColor),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            child: const Text(
                              '삭제',
                              style: TextStyle(color: ReaderThemeData.errorColor),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && modalContext.mounted) {
                      Navigator.of(modalContext).pop();
                      await ref.read(bookshelfControllerProvider.notifier).removeBook(book.id);
                    }
                  },
                  child: Text('서재에서 삭제', style: TextStyle(color: themeData.textColor)),
                ),
                const SizedBox(height: 12),
                ShadButton.ghost(
                  onPressed: () => Navigator.of(modalContext).pop(),
                  child: Text('닫기', style: TextStyle(color: themeData.textColor)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
