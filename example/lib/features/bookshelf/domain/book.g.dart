// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BookImpl _$$BookImplFromJson(Map<String, dynamic> json) => _$BookImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  author: json['author'] as String,
  filePath: json['filePath'] as String,
  coverImagePath: json['coverImagePath'] as String?,
  addedAt: DateTime.parse(json['addedAt'] as String),
);

Map<String, dynamic> _$$BookImplToJson(_$BookImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'author': instance.author,
      'filePath': instance.filePath,
      'coverImagePath': instance.coverImagePath,
      'addedAt': instance.addedAt.toIso8601String(),
    };
