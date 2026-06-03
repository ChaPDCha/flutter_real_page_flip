import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/book.dart';
import '../domain/book_repository.dart';

class SharedPreferencesBookRepository implements BookRepository {
  static const _booksKey = 'bookshelf_books';

  @override
  Future<List<Book>> getBooks() async {
    final prefs = await SharedPreferences.getInstance();
    final booksJson = prefs.getStringList(_booksKey) ?? [];
    return booksJson.map((jsonStr) {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return Book.fromJson(map);
    }).toList();
  }

  @override
  Future<void> addBook(Book book) async {
    final prefs = await SharedPreferences.getInstance();
    final books = await getBooks();
    
    // Remove if duplicates exist
    books.removeWhere((b) => b.id == book.id);
    books.add(book);

    final booksJson = books.map((b) => json.encode(b.toJson())).toList();
    await prefs.setStringList(_booksKey, booksJson);
  }

  @override
  Future<void> removeBook(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final books = await getBooks();
    books.removeWhere((b) => b.id == id);
    final booksJson = books.map((b) => json.encode(b.toJson())).toList();
    await prefs.setStringList(_booksKey, booksJson);
  }
}
