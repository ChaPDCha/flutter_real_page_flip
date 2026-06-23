import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_progress.freezed.dart';
part 'reading_progress.g.dart';

@freezed
class ReadingProgress with _$ReadingProgress {
  const factory ReadingProgress({
    required String bookId,
    @Default(0) int chapterIndex,
    @Default(0) int pageIndex,
    required DateTime lastReadAt,
  }) = _ReadingProgress;

  factory ReadingProgress.fromJson(Map<String, dynamic> json) =>
      _$ReadingProgressFromJson(json);
}
