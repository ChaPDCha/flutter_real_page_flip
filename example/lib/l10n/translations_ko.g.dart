///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'translations.g.dart';

// Path: <root>
class TranslationsKo extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsKo({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ko,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ko>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsKo _root = this; // ignore: unused_field

	@override 
	TranslationsKo $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsKo(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$ko app = _Translations$app$ko._(_root);
	@override late final _Translations$bookshelf$ko bookshelf = _Translations$bookshelf$ko._(_root);
	@override late final _Translations$settingsPanel$ko settingsPanel = _Translations$settingsPanel$ko._(_root);
	@override late final _Translations$readerSettings$ko readerSettings = _Translations$readerSettings$ko._(_root);
	@override late final _Translations$reader$ko reader = _Translations$reader$ko._(_root);
	@override late final _Translations$readerBar$ko readerBar = _Translations$readerBar$ko._(_root);
	@override late final _Translations$readerSearch$ko readerSearch = _Translations$readerSearch$ko._(_root);
}

// Path: app
class _Translations$app$ko extends Translations$app$en {
	_Translations$app$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$ko extends Translations$bookshelf$en {
	_Translations$bookshelf$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '서재';
	@override String get settings => '서재 설정';
	@override String get addBook => '책 추가 (EPUB, TXT, PDF)';
	@override String get emptyTitle => '서재가 비어 있습니다';
	@override String get emptyDescription => '오른쪽 상단의 + 버튼을 누르거나 아래 버튼을 눌러\n전자책 파일(EPUB, TXT, PDF)을 서재에 추가해 보세요.';
	@override String get importButton => '책 파일 가져오기';
	@override String get error => '오류가 발생했습니다:';
	@override String get retry => '다시 시도';
	@override String get close => '닫기';
	@override late final _Translations$bookshelf$book$ko book = _Translations$bookshelf$book$ko._(_root);
	@override late final _Translations$bookshelf$deleteDialog$ko deleteDialog = _Translations$bookshelf$deleteDialog$ko._(_root);
	@override late final _Translations$bookshelf$importFailed$ko importFailed = _Translations$bookshelf$importFailed$ko._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$ko extends Translations$settingsPanel$en {
	_Translations$settingsPanel$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '서재 설정';
	@override String get cloudSync => '클라우드 동기화';
	@override String get syncStatus => '동기화 상태';
	@override String get syncNow => '지금 동기화';
	@override String get appInfo => '애플리케이션 정보';
	@override String get version => '버전';
	@override String get engine => '엔진';
	@override String get status => '상태';
	@override String get darkMode => '다크 모드 활성화됨';
	@override String get done => '설정 완료';
	@override String get syncWaiting => '대기 중';
	@override String get syncVerifying => '인증 확인 중...';
	@override String get syncing => '동기화 중...';
	@override String get syncCompleted => '동기화 완료';
	@override String get syncError => '동기화 중 오류 발생';
}

// Path: readerSettings
class _Translations$readerSettings$ko extends Translations$readerSettings$en {
	_Translations$readerSettings$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '독서 설정';
	@override String get fontSize => '글자 크기';
	@override String get lineSpacing => '줄 간격';
	@override String get brightness => '화면 밝기';
	@override String get font => '글꼴';
	@override String get haptics => '햅틱 피드백';
	@override String get doublePage => '2단 보기';
	@override String get texture => '종이 질감';
	@override String get sound => '소리 효과';
	@override String get done => '설정 완료';
	@override late final _Translations$readerSettings$fontOptions$ko fontOptions = _Translations$readerSettings$fontOptions$ko._(_root);
	@override late final _Translations$readerSettings$textureOptions$ko textureOptions = _Translations$readerSettings$textureOptions$ko._(_root);
}

// Path: reader
class _Translations$reader$ko extends Translations$reader$en {
	_Translations$reader$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get loading => '로딩 중...';
	@override String get loadingBook => '책을 불러오는 중...';
	@override String get search => '검색';
}

// Path: readerBar
class _Translations$readerBar$ko extends Translations$readerBar$en {
	_Translations$readerBar$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => '이전 장';
	@override String get nextChapter => '다음 장';
	@override String get pageNum => '페이지';
}

// Path: readerSearch
class _Translations$readerSearch$ko extends Translations$readerSearch$en {
	_Translations$readerSearch$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get hint => '책 내용 검색...';
	@override String get close => '닫기';
	@override String get emptyPrompt => '검색어를 입력해 보세요.';
	@override String get noResults => '검색 결과가 없습니다.';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$ko extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get author => '저자:';
	@override String get read => '책 읽기';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$ko extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '책 삭제';
	@override String get message => '책을 서재에서 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
	@override String get cancel => '취소';
	@override String get delete => '삭제';
	@override String get removeFromShelf => '서재에서 삭제';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$ko extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '가져오기 실패';
	@override String get body => '책 가져오기에 실패했습니다:';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$ko extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get gothic => '기본 고딕';
	@override String get myungjo => '바른 명조';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$ko extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get smooth => '얇은';
	@override String get standard => '보통';
	@override String get textured => '거친';
	@override String get kraft => '크래프트';
}

/// The flat map containing all translations for locale <ko>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsKo {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => '서재',
			'bookshelf.settings' => '서재 설정',
			'bookshelf.addBook' => '책 추가 (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => '서재가 비어 있습니다',
			'bookshelf.emptyDescription' => '오른쪽 상단의 + 버튼을 누르거나 아래 버튼을 눌러\n전자책 파일(EPUB, TXT, PDF)을 서재에 추가해 보세요.',
			'bookshelf.importButton' => '책 파일 가져오기',
			'bookshelf.error' => '오류가 발생했습니다:',
			'bookshelf.retry' => '다시 시도',
			'bookshelf.close' => '닫기',
			'bookshelf.book.author' => '저자:',
			'bookshelf.book.read' => '책 읽기',
			'bookshelf.deleteDialog.title' => '책 삭제',
			'bookshelf.deleteDialog.message' => '책을 서재에서 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
			'bookshelf.deleteDialog.cancel' => '취소',
			'bookshelf.deleteDialog.delete' => '삭제',
			'bookshelf.deleteDialog.removeFromShelf' => '서재에서 삭제',
			'bookshelf.importFailed.title' => '가져오기 실패',
			'bookshelf.importFailed.body' => '책 가져오기에 실패했습니다:',
			'settingsPanel.title' => '서재 설정',
			'settingsPanel.cloudSync' => '클라우드 동기화',
			'settingsPanel.syncStatus' => '동기화 상태',
			'settingsPanel.syncNow' => '지금 동기화',
			'settingsPanel.appInfo' => '애플리케이션 정보',
			'settingsPanel.version' => '버전',
			'settingsPanel.engine' => '엔진',
			'settingsPanel.status' => '상태',
			'settingsPanel.darkMode' => '다크 모드 활성화됨',
			'settingsPanel.done' => '설정 완료',
			'settingsPanel.syncWaiting' => '대기 중',
			'settingsPanel.syncVerifying' => '인증 확인 중...',
			'settingsPanel.syncing' => '동기화 중...',
			'settingsPanel.syncCompleted' => '동기화 완료',
			'settingsPanel.syncError' => '동기화 중 오류 발생',
			'readerSettings.title' => '독서 설정',
			'readerSettings.fontSize' => '글자 크기',
			'readerSettings.lineSpacing' => '줄 간격',
			'readerSettings.brightness' => '화면 밝기',
			'readerSettings.font' => '글꼴',
			'readerSettings.haptics' => '햅틱 피드백',
			'readerSettings.doublePage' => '2단 보기',
			'readerSettings.texture' => '종이 질감',
			'readerSettings.sound' => '소리 효과',
			'readerSettings.done' => '설정 완료',
			'readerSettings.fontOptions.gothic' => '기본 고딕',
			'readerSettings.fontOptions.myungjo' => '바른 명조',
			'readerSettings.textureOptions.smooth' => '얇은',
			'readerSettings.textureOptions.standard' => '보통',
			'readerSettings.textureOptions.textured' => '거친',
			'readerSettings.textureOptions.kraft' => '크래프트',
			'reader.loading' => '로딩 중...',
			'reader.loadingBook' => '책을 불러오는 중...',
			'reader.search' => '검색',
			'readerBar.prevChapter' => '이전 장',
			'readerBar.nextChapter' => '다음 장',
			'readerBar.pageNum' => '페이지',
			'readerSearch.hint' => '책 내용 검색...',
			'readerSearch.close' => '닫기',
			'readerSearch.emptyPrompt' => '검색어를 입력해 보세요.',
			'readerSearch.noResults' => '검색 결과가 없습니다.',
			_ => null,
		};
	}
}
