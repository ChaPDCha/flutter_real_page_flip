import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../domain/book_repository.dart';
import 'database.dart';
import 'drift_book_repository.dart';
import 'shared_preferences_book_repository.dart';
import '../../../shared/firebase/firebase_service.dart';

part 'book_repository_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(AppDatabaseRef ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
}

@Riverpod(keepAlive: true)
BookRepository bookRepository(BookRepositoryRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = DriftBookRepository(db);

  // Trigger background migration from SharedPreferences to SQLite on startup
  _migrateFromSharedPreferences(repo);

  return repo;
}

Future<void> _migrateFromSharedPreferences(DriftBookRepository newRepo) async {
  try {
    final oldRepo = SharedPreferencesBookRepository();
    final oldBooks = await oldRepo.getBooks();
    if (oldBooks.isNotEmpty) {
      for (final book in oldBooks) {
        await newRepo.addBook(book);
      }
      // Clear migrated books from SharedPreferences
      for (final book in oldBooks) {
        await oldRepo.removeBook(book.id);
      }
    }
  } catch (e, st) {
    FirebaseService.recordError(
      e,
      st,
      reason: 'SharedPreferences → Drift migration',
    );
  }
}
