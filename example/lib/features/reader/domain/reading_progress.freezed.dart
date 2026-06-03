// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_progress.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ReadingProgress _$ReadingProgressFromJson(Map<String, dynamic> json) {
  return _ReadingProgress.fromJson(json);
}

/// @nodoc
mixin _$ReadingProgress {
  String get bookId => throw _privateConstructorUsedError;
  int get chapterIndex => throw _privateConstructorUsedError;
  int get pageIndex => throw _privateConstructorUsedError;
  DateTime get lastReadAt => throw _privateConstructorUsedError;

  /// Serializes this ReadingProgress to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ReadingProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReadingProgressCopyWith<ReadingProgress> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReadingProgressCopyWith<$Res> {
  factory $ReadingProgressCopyWith(
    ReadingProgress value,
    $Res Function(ReadingProgress) then,
  ) = _$ReadingProgressCopyWithImpl<$Res, ReadingProgress>;
  @useResult
  $Res call({
    String bookId,
    int chapterIndex,
    int pageIndex,
    DateTime lastReadAt,
  });
}

/// @nodoc
class _$ReadingProgressCopyWithImpl<$Res, $Val extends ReadingProgress>
    implements $ReadingProgressCopyWith<$Res> {
  _$ReadingProgressCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReadingProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookId = null,
    Object? chapterIndex = null,
    Object? pageIndex = null,
    Object? lastReadAt = null,
  }) {
    return _then(
      _value.copyWith(
            bookId: null == bookId
                ? _value.bookId
                : bookId // ignore: cast_nullable_to_non_nullable
                      as String,
            chapterIndex: null == chapterIndex
                ? _value.chapterIndex
                : chapterIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            pageIndex: null == pageIndex
                ? _value.pageIndex
                : pageIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            lastReadAt: null == lastReadAt
                ? _value.lastReadAt
                : lastReadAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ReadingProgressImplCopyWith<$Res>
    implements $ReadingProgressCopyWith<$Res> {
  factory _$$ReadingProgressImplCopyWith(
    _$ReadingProgressImpl value,
    $Res Function(_$ReadingProgressImpl) then,
  ) = __$$ReadingProgressImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String bookId,
    int chapterIndex,
    int pageIndex,
    DateTime lastReadAt,
  });
}

/// @nodoc
class __$$ReadingProgressImplCopyWithImpl<$Res>
    extends _$ReadingProgressCopyWithImpl<$Res, _$ReadingProgressImpl>
    implements _$$ReadingProgressImplCopyWith<$Res> {
  __$$ReadingProgressImplCopyWithImpl(
    _$ReadingProgressImpl _value,
    $Res Function(_$ReadingProgressImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReadingProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? bookId = null,
    Object? chapterIndex = null,
    Object? pageIndex = null,
    Object? lastReadAt = null,
  }) {
    return _then(
      _$ReadingProgressImpl(
        bookId: null == bookId
            ? _value.bookId
            : bookId // ignore: cast_nullable_to_non_nullable
                  as String,
        chapterIndex: null == chapterIndex
            ? _value.chapterIndex
            : chapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        pageIndex: null == pageIndex
            ? _value.pageIndex
            : pageIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        lastReadAt: null == lastReadAt
            ? _value.lastReadAt
            : lastReadAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ReadingProgressImpl implements _ReadingProgress {
  const _$ReadingProgressImpl({
    required this.bookId,
    this.chapterIndex = 0,
    this.pageIndex = 0,
    required this.lastReadAt,
  });

  factory _$ReadingProgressImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReadingProgressImplFromJson(json);

  @override
  final String bookId;
  @override
  @JsonKey()
  final int chapterIndex;
  @override
  @JsonKey()
  final int pageIndex;
  @override
  final DateTime lastReadAt;

  @override
  String toString() {
    return 'ReadingProgress(bookId: $bookId, chapterIndex: $chapterIndex, pageIndex: $pageIndex, lastReadAt: $lastReadAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReadingProgressImpl &&
            (identical(other.bookId, bookId) || other.bookId == bookId) &&
            (identical(other.chapterIndex, chapterIndex) ||
                other.chapterIndex == chapterIndex) &&
            (identical(other.pageIndex, pageIndex) ||
                other.pageIndex == pageIndex) &&
            (identical(other.lastReadAt, lastReadAt) ||
                other.lastReadAt == lastReadAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, bookId, chapterIndex, pageIndex, lastReadAt);

  /// Create a copy of ReadingProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReadingProgressImplCopyWith<_$ReadingProgressImpl> get copyWith =>
      __$$ReadingProgressImplCopyWithImpl<_$ReadingProgressImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ReadingProgressImplToJson(this);
  }
}

abstract class _ReadingProgress implements ReadingProgress {
  const factory _ReadingProgress({
    required final String bookId,
    final int chapterIndex,
    final int pageIndex,
    required final DateTime lastReadAt,
  }) = _$ReadingProgressImpl;

  factory _ReadingProgress.fromJson(Map<String, dynamic> json) =
      _$ReadingProgressImpl.fromJson;

  @override
  String get bookId;
  @override
  int get chapterIndex;
  @override
  int get pageIndex;
  @override
  DateTime get lastReadAt;

  /// Create a copy of ReadingProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReadingProgressImplCopyWith<_$ReadingProgressImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
