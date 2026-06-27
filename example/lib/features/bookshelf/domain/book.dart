import 'package:freezed_annotation/freezed_annotation.dart';

part 'book.freezed.dart';
part 'book.g.dart';

@freezed
class Book with _$Book {
  const factory Book({
    required String id,
    required String title,
    required String author,
    required String filePath,
    String? coverImagePath,
    required DateTime addedAt,
  }) = _Book;

  factory Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);
}

enum BookFormat { epub, txt, pdf }

extension BookFormatExtension on Book {
  BookFormat get format {
    final ext = filePath.split('.').last.toLowerCase();
    if (ext == 'epub') return BookFormat.epub;
    if (ext == 'txt') return BookFormat.txt;
    if (ext == 'pdf') return BookFormat.pdf;
    throw UnsupportedError('Unsupported book format: "$ext". Supported formats: epub, pdf, txt.');
  }
}
