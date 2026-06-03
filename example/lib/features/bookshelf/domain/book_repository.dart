import 'book.dart';

abstract class BookRepository {
  Future<List<Book>> getBooks();
  Future<void> addBook(Book book);
  Future<void> removeBook(String id);
}
