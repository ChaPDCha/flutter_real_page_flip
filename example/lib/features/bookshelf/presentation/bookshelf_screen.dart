import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/theme/reader_theme.dart';
import '../../../shared/theme/reader_theme_dialogs.dart';
import '../../../shared/theme/reader_typography.dart';
import '../../../l10n/translations.g.dart';
import '../../ads/presentation/adaptive_banner_ad.dart';
import 'bookshelf_controller.dart';
import '../domain/book.dart';
import '../../reader/presentation/book_reader_screen.dart';
import 'widgets/bookshelf_settings_panel.dart';

class BookshelfScreen extends ConsumerWidget {
  const BookshelfScreen({super.key});

  static bool _filePickerInProgress = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookshelfState = ref.watch(bookshelfControllerProvider);
    const themeData = ReaderThemeData.charcoal; // Unified to dark mode
    final l10n = context.t;

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium minimalist top header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.bookshelf.title,
                      style: ReaderTypography.getUiStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeData.textColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.settings_outlined,
                            color: themeData.textColor,
                            size: 22,
                          ),
                          onPressed: () => BookshelfSettingsPanel.show(
                            context: context,
                            ref: ref,
                          ),
                          tooltip: l10n.bookshelf.settings,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: themeData.textColor,
                            size: 24,
                          ),
                          onPressed: () => _pickAndImportEpub(context, ref),
                          tooltip: l10n.bookshelf.addBook,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Books list/grid
            bookshelfState.when(
              data: (books) => books.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(context, ref, themeData),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 8.0,
                      ),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.55,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 28,
                            ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final book = books[index];
                          return _buildBookCard(context, ref, book, themeData);
                        }, childCount: books.length),
                      ),
                    ),
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                sliver: _buildSkeletonSliverGrid(themeData),
              ),
              error: (err, stack) => SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(err, themeData, ref, context),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AdaptiveBannerAdWidget(),
    );
  }

  Widget _buildSkeletonSliverGrid(ReaderThemeData themeData) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 20,
        mainAxisSpacing: 28,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => Skeletonizer(
          enabled: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  color: themeData.panelColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 14,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: themeData.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  color: themeData.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        childCount: 6,
      ),
    );
  }

  Widget _buildErrorState(
    Object err,
    ReaderThemeData themeData,
    WidgetRef ref,
    BuildContext context,
  ) {
    final l10n = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: ReaderThemeData.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.bookshelf.error}\n$err',
              textAlign: TextAlign.center,
              style: ReaderTypography.getUiStyle(color: themeData.textColor),
            ),
            const SizedBox(height: 16),
            ShadButton(
              onPressed: () => ref.refresh(bookshelfControllerProvider),
              backgroundColor: themeData.accentColor,
              child: Text(
                l10n.bookshelf.retry,
                style: ReaderTypography.getUiStyle(
                  color: themeData.buttonForegroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    ReaderThemeData themeData,
  ) {
    final l10n = context.t;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: themeData.secondaryTextColor.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.bookshelf.emptyTitle,
              style: ReaderTypography.getUiStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: themeData.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.bookshelf.emptyDescription,
              textAlign: TextAlign.center,
              style: ReaderTypography.getUiStyle(
                fontSize: 13,
                color: themeData.secondaryTextColor,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 28),
            ShadButton(
              onPressed: () => _pickAndImportEpub(context, ref),
              backgroundColor: themeData.accentColor,
              foregroundColor: themeData.buttonForegroundColor,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_open_outlined,
                    size: 16,
                    color: themeData.buttonForegroundColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.bookshelf.importButton,
                    style: ReaderTypography.getUiStyle(
                      fontWeight: FontWeight.bold,
                      color: themeData.buttonForegroundColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          MaterialPageRoute(builder: (context) => BookReaderScreen(book: book)),
        );
      },
      onLongPress: () => _showBookActionsSheet(context, ref, book, themeData),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeData.textColor.withValues(alpha: 0.08),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
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
          const SizedBox(height: 10),
          Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ReaderTypography.getUiStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: themeData.textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ReaderTypography.getUiStyle(
              fontSize: 11,
              color: themeData.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCover(Book book, ReaderThemeData themeData) {
    final hash = book.title.hashCode;
    final List<Color> gradientColors = _getDeterministicColors(hash);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: 0.08,
              child: Text(
                book.title.isNotEmpty ? book.title.substring(0, 1) : 'B',
                style: GoogleFonts.notoSerifKr(
                  fontSize: 72,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: Colors.white.withValues(alpha: 0.4),
                size: 14,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      book.title,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSerifKr(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
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
                  style: ReaderTypography.getGeometricStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Color> _getDeterministicColors(int hash) {
    final List<List<Color>> palettes = [
      [const Color(0xFF1E293B), const Color(0xFF0F172A)],
      [const Color(0xFF2C1B18), const Color(0xFF180E0D)],
      [const Color(0xFF142C1D), const Color(0xFF0B1910)],
      [const Color(0xFF2D1B36), const Color(0xFF190E1F)],
      [const Color(0xFF1E272C), const Color(0xFF11171A)],
      [const Color(0xFF3F2B1B), const Color(0xFF22160E)],
    ];
    final index = hash.abs() % palettes.length;
    return palettes[index];
  }

  Future<void> _pickAndImportEpub(BuildContext context, WidgetRef ref) async {
    if (_filePickerInProgress) return;
    _filePickerInProgress = true;
    final l10n = context.t;
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
            title: Text(l10n.bookshelf.importFailed.title),
            description: Text(
              '${l10n.bookshelf.importFailed.body} ${e.message ?? e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: Text(l10n.bookshelf.importFailed.title),
            description: Text('${l10n.bookshelf.importFailed.body} $e'),
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
    final l10n = context.t;
    WoltModalSheet.show(
      context: context,
      pageListBuilder: (modalContext) => [
        WoltModalSheetPage(
          backgroundColor: themeData.panelColor,
          topBarTitle: Text(
            book.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.notoSerifKr(
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
                  '${l10n.bookshelf.book.author} ${book.author}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ReaderTypography.getUiStyle(
                    fontSize: 13,
                    color: themeData.secondaryTextColor,
                  ),
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
                  child: Text(
                    l10n.bookshelf.book.read,
                    style: ReaderTypography.getUiStyle(
                      fontWeight: FontWeight.bold,
                      color: themeData.buttonForegroundColor,
                    ),
                  ),
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
                          l10n.bookshelf.deleteDialog.title,
                          style: ReaderTypography.getUiStyle(
                            color: themeData.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          '"${book.title}"\n${l10n.bookshelf.deleteDialog.message}',
                          style: ReaderTypography.getUiStyle(
                            color: themeData.secondaryTextColor,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(
                              l10n.bookshelf.deleteDialog.cancel,
                              style: ReaderTypography.getUiStyle(
                                color: themeData.secondaryTextColor,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(
                              l10n.bookshelf.deleteDialog.delete,
                              style: ReaderTypography.getUiStyle(
                                color: ReaderThemeData.errorColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && modalContext.mounted) {
                      Navigator.of(modalContext).pop();
                      await ref
                          .read(bookshelfControllerProvider.notifier)
                          .removeBook(book.id);
                    }
                  },
                  child: Text(
                    l10n.bookshelf.deleteDialog.removeFromShelf,
                    style: ReaderTypography.getUiStyle(
                      color: themeData.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ShadButton.ghost(
                  onPressed: () => Navigator.of(modalContext).pop(),
                  child: Text(
                    l10n.bookshelf.close,
                    style: ReaderTypography.getUiStyle(
                      color: themeData.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
