import 'package:epubx/epubx.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../bookshelf/domain/book.dart';
import '../../bookshelf/data/database.dart';
import '../domain/reader_settings.dart';

part 'reader_state.freezed.dart';

@freezed
class ReaderState with _$ReaderState {
  const ReaderState._();

  const factory ReaderState({
    required Book book,
    EpubBook? epubBook,
    @Default([]) List<EpubChapter> chapters,
    @Default(0) int currentChapterIndex,
    @Default(0) int currentPageIndex,
    @Default([]) List<String> pages,
    @Default([]) List<Highlight> highlights,
    @Default(ReaderSettings()) ReaderSettings settings,
    @Default(true) bool isLoading,
    @Default(0.0) double viewportWidth,
    @Default(0.0) double viewportHeight,
    @Default(false) bool isPdfLandscape,
  }) = _ReaderState;

  bool get isDoublePage =>
      settings.enableDoublePage ||
      (viewportWidth > 600 && viewportWidth >= viewportHeight);
}
