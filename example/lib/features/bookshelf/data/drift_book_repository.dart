import 'package:drift/drift.dart';
import '../domain/book.dart';
import '../domain/book_repository.dart';
import 'database.dart';

class DriftBookRepository implements BookRepository {
  final AppDatabase _db;

  DriftBookRepository(this._db);

  @override
  Future<List<Book>> getBooks() async {
    final rows = await _db.select(_db.books).get();
    return rows.map((row) {
      return Book(
        id: row.id,
        title: row.title,
        author: row.author,
        filePath: row.filePath,
        coverImagePath: row.coverPath,
        addedAt: row.addedAt,
      );
    }).toList();
  }

  @override
  Future<void> addBook(Book book) async {
    await _db.into(_db.books).insertOnConflictUpdate(
      BooksCompanion(
        id: Value(book.id),
        title: Value(book.title),
        author: Value(book.author),
        filePath: Value(book.filePath),
        coverPath: Value(book.coverImagePath),
        addedAt: Value(book.addedAt),
        format: Value(book.filePath.split('.').last.toLowerCase()),
      ),
    );
  }

  @override
  Future<void> removeBook(String id) async {
    await (_db.delete(_db.books)..where((tbl) => tbl.id.equals(id))).go();
  }
}
