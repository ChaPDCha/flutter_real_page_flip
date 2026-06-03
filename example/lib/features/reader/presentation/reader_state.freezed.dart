// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ReaderState {
  Book get book => throw _privateConstructorUsedError;
  EpubBook? get epubBook => throw _privateConstructorUsedError;
  List<EpubChapter> get chapters => throw _privateConstructorUsedError;
  int get currentChapterIndex => throw _privateConstructorUsedError;
  int get currentPageIndex => throw _privateConstructorUsedError;
  List<String> get pages => throw _privateConstructorUsedError;
  List<Highlight> get highlights => throw _privateConstructorUsedError;
  ReaderSettings get settings => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  double get viewportWidth => throw _privateConstructorUsedError;
  double get viewportHeight => throw _privateConstructorUsedError;
  bool get isPdfLandscape => throw _privateConstructorUsedError;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReaderStateCopyWith<ReaderState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReaderStateCopyWith<$Res> {
  factory $ReaderStateCopyWith(
    ReaderState value,
    $Res Function(ReaderState) then,
  ) = _$ReaderStateCopyWithImpl<$Res, ReaderState>;
  @useResult
  $Res call({
    Book book,
    EpubBook? epubBook,
    List<EpubChapter> chapters,
    int currentChapterIndex,
    int currentPageIndex,
    List<String> pages,
    List<Highlight> highlights,
    ReaderSettings settings,
    bool isLoading,
    double viewportWidth,
    double viewportHeight,
    bool isPdfLandscape,
  });

  $BookCopyWith<$Res> get book;
  $ReaderSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class _$ReaderStateCopyWithImpl<$Res, $Val extends ReaderState>
    implements $ReaderStateCopyWith<$Res> {
  _$ReaderStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? book = null,
    Object? epubBook = freezed,
    Object? chapters = null,
    Object? currentChapterIndex = null,
    Object? currentPageIndex = null,
    Object? pages = null,
    Object? highlights = null,
    Object? settings = null,
    Object? isLoading = null,
    Object? viewportWidth = null,
    Object? viewportHeight = null,
    Object? isPdfLandscape = null,
  }) {
    return _then(
      _value.copyWith(
            book: null == book
                ? _value.book
                : book // ignore: cast_nullable_to_non_nullable
                      as Book,
            epubBook: freezed == epubBook
                ? _value.epubBook
                : epubBook // ignore: cast_nullable_to_non_nullable
                      as EpubBook?,
            chapters: null == chapters
                ? _value.chapters
                : chapters // ignore: cast_nullable_to_non_nullable
                      as List<EpubChapter>,
            currentChapterIndex: null == currentChapterIndex
                ? _value.currentChapterIndex
                : currentChapterIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            currentPageIndex: null == currentPageIndex
                ? _value.currentPageIndex
                : currentPageIndex // ignore: cast_nullable_to_non_nullable
                      as int,
            pages: null == pages
                ? _value.pages
                : pages // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            highlights: null == highlights
                ? _value.highlights
                : highlights // ignore: cast_nullable_to_non_nullable
                      as List<Highlight>,
            settings: null == settings
                ? _value.settings
                : settings // ignore: cast_nullable_to_non_nullable
                      as ReaderSettings,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            viewportWidth: null == viewportWidth
                ? _value.viewportWidth
                : viewportWidth // ignore: cast_nullable_to_non_nullable
                      as double,
            viewportHeight: null == viewportHeight
                ? _value.viewportHeight
                : viewportHeight // ignore: cast_nullable_to_non_nullable
                      as double,
            isPdfLandscape: null == isPdfLandscape
                ? _value.isPdfLandscape
                : isPdfLandscape // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BookCopyWith<$Res> get book {
    return $BookCopyWith<$Res>(_value.book, (value) {
      return _then(_value.copyWith(book: value) as $Val);
    });
  }

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ReaderSettingsCopyWith<$Res> get settings {
    return $ReaderSettingsCopyWith<$Res>(_value.settings, (value) {
      return _then(_value.copyWith(settings: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ReaderStateImplCopyWith<$Res>
    implements $ReaderStateCopyWith<$Res> {
  factory _$$ReaderStateImplCopyWith(
    _$ReaderStateImpl value,
    $Res Function(_$ReaderStateImpl) then,
  ) = __$$ReaderStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Book book,
    EpubBook? epubBook,
    List<EpubChapter> chapters,
    int currentChapterIndex,
    int currentPageIndex,
    List<String> pages,
    List<Highlight> highlights,
    ReaderSettings settings,
    bool isLoading,
    double viewportWidth,
    double viewportHeight,
    bool isPdfLandscape,
  });

  @override
  $BookCopyWith<$Res> get book;
  @override
  $ReaderSettingsCopyWith<$Res> get settings;
}

/// @nodoc
class __$$ReaderStateImplCopyWithImpl<$Res>
    extends _$ReaderStateCopyWithImpl<$Res, _$ReaderStateImpl>
    implements _$$ReaderStateImplCopyWith<$Res> {
  __$$ReaderStateImplCopyWithImpl(
    _$ReaderStateImpl _value,
    $Res Function(_$ReaderStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? book = null,
    Object? epubBook = freezed,
    Object? chapters = null,
    Object? currentChapterIndex = null,
    Object? currentPageIndex = null,
    Object? pages = null,
    Object? highlights = null,
    Object? settings = null,
    Object? isLoading = null,
    Object? viewportWidth = null,
    Object? viewportHeight = null,
    Object? isPdfLandscape = null,
  }) {
    return _then(
      _$ReaderStateImpl(
        book: null == book
            ? _value.book
            : book // ignore: cast_nullable_to_non_nullable
                  as Book,
        epubBook: freezed == epubBook
            ? _value.epubBook
            : epubBook // ignore: cast_nullable_to_non_nullable
                  as EpubBook?,
        chapters: null == chapters
            ? _value._chapters
            : chapters // ignore: cast_nullable_to_non_nullable
                  as List<EpubChapter>,
        currentChapterIndex: null == currentChapterIndex
            ? _value.currentChapterIndex
            : currentChapterIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        currentPageIndex: null == currentPageIndex
            ? _value.currentPageIndex
            : currentPageIndex // ignore: cast_nullable_to_non_nullable
                  as int,
        pages: null == pages
            ? _value._pages
            : pages // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        highlights: null == highlights
            ? _value._highlights
            : highlights // ignore: cast_nullable_to_non_nullable
                  as List<Highlight>,
        settings: null == settings
            ? _value.settings
            : settings // ignore: cast_nullable_to_non_nullable
                  as ReaderSettings,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        viewportWidth: null == viewportWidth
            ? _value.viewportWidth
            : viewportWidth // ignore: cast_nullable_to_non_nullable
                  as double,
        viewportHeight: null == viewportHeight
            ? _value.viewportHeight
            : viewportHeight // ignore: cast_nullable_to_non_nullable
                  as double,
        isPdfLandscape: null == isPdfLandscape
            ? _value.isPdfLandscape
            : isPdfLandscape // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc

class _$ReaderStateImpl extends _ReaderState {
  const _$ReaderStateImpl({
    required this.book,
    this.epubBook,
    final List<EpubChapter> chapters = const [],
    this.currentChapterIndex = 0,
    this.currentPageIndex = 0,
    final List<String> pages = const [],
    final List<Highlight> highlights = const [],
    this.settings = const ReaderSettings(),
    this.isLoading = true,
    this.viewportWidth = 0.0,
    this.viewportHeight = 0.0,
    this.isPdfLandscape = false,
  }) : _chapters = chapters,
       _pages = pages,
       _highlights = highlights,
       super._();

  @override
  final Book book;
  @override
  final EpubBook? epubBook;
  final List<EpubChapter> _chapters;
  @override
  @JsonKey()
  List<EpubChapter> get chapters {
    if (_chapters is EqualUnmodifiableListView) return _chapters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_chapters);
  }

  @override
  @JsonKey()
  final int currentChapterIndex;
  @override
  @JsonKey()
  final int currentPageIndex;
  final List<String> _pages;
  @override
  @JsonKey()
  List<String> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  final List<Highlight> _highlights;
  @override
  @JsonKey()
  List<Highlight> get highlights {
    if (_highlights is EqualUnmodifiableListView) return _highlights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_highlights);
  }

  @override
  @JsonKey()
  final ReaderSettings settings;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final double viewportWidth;
  @override
  @JsonKey()
  final double viewportHeight;
  @override
  @JsonKey()
  final bool isPdfLandscape;

  @override
  String toString() {
    return 'ReaderState(book: $book, epubBook: $epubBook, chapters: $chapters, currentChapterIndex: $currentChapterIndex, currentPageIndex: $currentPageIndex, pages: $pages, highlights: $highlights, settings: $settings, isLoading: $isLoading, viewportWidth: $viewportWidth, viewportHeight: $viewportHeight, isPdfLandscape: $isPdfLandscape)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReaderStateImpl &&
            (identical(other.book, book) || other.book == book) &&
            (identical(other.epubBook, epubBook) ||
                other.epubBook == epubBook) &&
            const DeepCollectionEquality().equals(other._chapters, _chapters) &&
            (identical(other.currentChapterIndex, currentChapterIndex) ||
                other.currentChapterIndex == currentChapterIndex) &&
            (identical(other.currentPageIndex, currentPageIndex) ||
                other.currentPageIndex == currentPageIndex) &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            const DeepCollectionEquality().equals(
              other._highlights,
              _highlights,
            ) &&
            (identical(other.settings, settings) ||
                other.settings == settings) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.viewportWidth, viewportWidth) ||
                other.viewportWidth == viewportWidth) &&
            (identical(other.viewportHeight, viewportHeight) ||
                other.viewportHeight == viewportHeight) &&
            (identical(other.isPdfLandscape, isPdfLandscape) ||
                other.isPdfLandscape == isPdfLandscape));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    book,
    epubBook,
    const DeepCollectionEquality().hash(_chapters),
    currentChapterIndex,
    currentPageIndex,
    const DeepCollectionEquality().hash(_pages),
    const DeepCollectionEquality().hash(_highlights),
    settings,
    isLoading,
    viewportWidth,
    viewportHeight,
    isPdfLandscape,
  );

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReaderStateImplCopyWith<_$ReaderStateImpl> get copyWith =>
      __$$ReaderStateImplCopyWithImpl<_$ReaderStateImpl>(this, _$identity);
}

abstract class _ReaderState extends ReaderState {
  const factory _ReaderState({
    required final Book book,
    final EpubBook? epubBook,
    final List<EpubChapter> chapters,
    final int currentChapterIndex,
    final int currentPageIndex,
    final List<String> pages,
    final List<Highlight> highlights,
    final ReaderSettings settings,
    final bool isLoading,
    final double viewportWidth,
    final double viewportHeight,
    final bool isPdfLandscape,
  }) = _$ReaderStateImpl;
  const _ReaderState._() : super._();

  @override
  Book get book;
  @override
  EpubBook? get epubBook;
  @override
  List<EpubChapter> get chapters;
  @override
  int get currentChapterIndex;
  @override
  int get currentPageIndex;
  @override
  List<String> get pages;
  @override
  List<Highlight> get highlights;
  @override
  ReaderSettings get settings;
  @override
  bool get isLoading;
  @override
  double get viewportWidth;
  @override
  double get viewportHeight;
  @override
  bool get isPdfLandscape;

  /// Create a copy of ReaderState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReaderStateImplCopyWith<_$ReaderStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
