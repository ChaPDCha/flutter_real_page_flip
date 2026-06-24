import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:epubx/epubx.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/book.dart';
import '../data/book_repository_provider.dart';
import '../../reader/application/search_service_provider.dart';
import '../../../shared/firebase/firebase_service.dart';
import 'demo_book_content.dart';

part 'bookshelf_controller.g.dart';

const String _demoBookId = 'book_demo';
const String _kDemoCreatedPref = 'demo_book_created';

@riverpod
class BookshelfController extends _$BookshelfController {
  @override
  FutureOr<List<Book>> build() async {
    final books = await _loadBooks();
    if (books.isEmpty) {
      await _ensureDemoBook();
      return _loadBooks();
    }
    return books;
  }

  Future<List<Book>> _loadBooks() {
    return ref.read(bookRepositoryProvider).getBooks();
  }

  Future<void> _ensureDemoBook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kDemoCreatedPref) == true) return;

      final docDir = await getApplicationDocumentsDirectory();

      // Create demo book directory
      final targetDir = Directory(p.join(docDir.path, 'books'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Generate demo TXT content
      final demoContent = generateDemoContent();
      final targetPath = p.join(targetDir.path, '$_demoBookId.txt');
      await File(targetPath).writeAsString(demoContent);

      final book = Book(
        id: _demoBookId,
        title: 'Realbook 데모',
        author: 'Realbook Team',
        filePath: targetPath,
        addedAt: DateTime.now(),
      );

      await ref.read(bookRepositoryProvider).addBook(book);
      await ref.read(searchServiceProvider).indexBook(book);
      await prefs.setBool(_kDemoCreatedPref, true);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Demo book creation');
    }
  }

  Future<void> importBook(File file) async {
    state = const AsyncValue.loading();
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalName = p.basenameWithoutExtension(file.path);
      final ext = p.extension(file.path).toLowerCase();
      final bookId = 'book_$timestamp';

      String title = originalName;
      String author = 'Unknown Author';
      String? coverImagePath;

      if (ext == '.epub') {
        // Read EPUB metadata
        final bytes = await file.readAsBytes();
        final epubBook = await compute(EpubReader.readBook, bytes);

        title = epubBook.Title?.trim().isNotEmpty == true
            ? epubBook.Title!
            : originalName;
        author = epubBook.Author?.trim().isNotEmpty == true
            ? epubBook.Author!
            : 'Unknown Author';

        // Save cover image if exists
        if (epubBook.CoverImage != null) {
          final coverDir = Directory(p.join(docDir.path, 'covers'));
          if (!await coverDir.exists()) {
            await coverDir.create(recursive: true);
          }
          final coverFile = File(p.join(coverDir.path, '$bookId.png'));
          final pngBytes = await compute(img.encodePng, epubBook.CoverImage!);
          await coverFile.writeAsBytes(pngBytes);
          coverImagePath = coverFile.path;
        }
      } else {
        // TXT or PDF defaults
        title = originalName;
        author = 'Unknown Author';
      }

      // Copy book file to documents directory
      final targetDir = Directory(p.join(docDir.path, 'books'));
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final targetPath = p.join(targetDir.path, '$bookId$ext');
      await file.copy(targetPath);

      final book = Book(
        id: bookId,
        title: title,
        author: author,
        filePath: targetPath,
        coverImagePath: coverImagePath,
        addedAt: DateTime.now(),
      );

      await ref.read(bookRepositoryProvider).addBook(book);
      ref.read(searchServiceProvider).indexBook(book);
      state = AsyncValue.data(await _loadBooks());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Alias for backward compatibility
  Future<void> importEpub(File file) => importBook(file);

  Future<void> removeBook(String id) async {
    state = const AsyncValue.loading();
    try {
      final books = await _loadBooks();
      final targetBook = books.firstWhere((b) => b.id == id);

      // Delete EPUB file
      final file = File(targetBook.filePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Delete cover image if exists
      if (targetBook.coverImagePath != null) {
        final coverFile = File(targetBook.coverImagePath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }

      await ref.read(bookRepositoryProvider).removeBook(id);
      state = AsyncValue.data(await _loadBooks());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
