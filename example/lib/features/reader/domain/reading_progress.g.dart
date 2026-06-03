// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reading_progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ReadingProgressImpl _$$ReadingProgressImplFromJson(
  Map<String, dynamic> json,
) => _$ReadingProgressImpl(
  bookId: json['bookId'] as String,
  chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
  pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
  lastReadAt: DateTime.parse(json['lastReadAt'] as String),
);

Map<String, dynamic> _$$ReadingProgressImplToJson(
  _$ReadingProgressImpl instance,
) => <String, dynamic>{
  'bookId': instance.bookId,
  'chapterIndex': instance.chapterIndex,
  'pageIndex': instance.pageIndex,
  'lastReadAt': instance.lastReadAt.toIso8601String(),
};
