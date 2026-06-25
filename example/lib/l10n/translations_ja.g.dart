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
class TranslationsJa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsJa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsJa _root = this; // ignore: unused_field

	@override 
	TranslationsJa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsJa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$ja app = _Translations$app$ja._(_root);
	@override late final _Translations$bookshelf$ja bookshelf = _Translations$bookshelf$ja._(_root);
	@override late final _Translations$settingsPanel$ja settingsPanel = _Translations$settingsPanel$ja._(_root);
	@override late final _Translations$readerSettings$ja readerSettings = _Translations$readerSettings$ja._(_root);
	@override late final _Translations$reader$ja reader = _Translations$reader$ja._(_root);
	@override late final _Translations$readerBar$ja readerBar = _Translations$readerBar$ja._(_root);
	@override late final _Translations$readerSearch$ja readerSearch = _Translations$readerSearch$ja._(_root);
}

// Path: app
class _Translations$app$ja extends Translations$app$en {
	_Translations$app$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$ja extends Translations$bookshelf$en {
	_Translations$bookshelf$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '本棚';
	@override String get settings => '本棚設定';
	@override String get addBook => '本を追加 (EPUB, TXT, PDF)';
	@override String get emptyTitle => '本棚は空です';
	@override String get emptyDescription => '右上の + ボタンをタップするか、下のボタンを使用して\nEPUB、TXT、PDF ファイルを追加してください。';
	@override String get importButton => '本をインポート';
	@override String get error => 'エラーが発生しました：';
	@override String get retry => '再試行';
	@override String get close => '閉じる';
	@override late final _Translations$bookshelf$book$ja book = _Translations$bookshelf$book$ja._(_root);
	@override late final _Translations$bookshelf$deleteDialog$ja deleteDialog = _Translations$bookshelf$deleteDialog$ja._(_root);
	@override late final _Translations$bookshelf$importFailed$ja importFailed = _Translations$bookshelf$importFailed$ja._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$ja extends Translations$settingsPanel$en {
	_Translations$settingsPanel$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '本棚設定';
	@override String get cloudSync => 'クラウド同期';
	@override String get syncStatus => '同期ステータス';
	@override String get syncNow => '今すぐ同期';
	@override String get appInfo => 'アプリケーション情報';
	@override String get version => 'バージョン';
	@override String get engine => 'エンジン';
	@override String get status => 'ステータス';
	@override String get darkMode => 'ダークモード有効';
	@override String get done => '完了';
	@override String get syncWaiting => '待機中';
	@override String get syncVerifying => '確認中...';
	@override String get syncing => '同期中...';
	@override String get syncCompleted => '同期完了';
	@override String get syncError => '同期エラー';
}

// Path: readerSettings
class _Translations$readerSettings$ja extends Translations$readerSettings$en {
	_Translations$readerSettings$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '読書設定';
	@override String get fontSize => 'フォントサイズ';
	@override String get lineSpacing => '行間';
	@override String get brightness => '明るさ';
	@override String get font => 'フォント';
	@override String get haptics => '触覚フィードバック';
	@override String get texture => '紙の質感';
	@override String get sound => '効果音';
	@override String get done => '完了';
	@override late final _Translations$readerSettings$fontOptions$ja fontOptions = _Translations$readerSettings$fontOptions$ja._(_root);
	@override late final _Translations$readerSettings$textureOptions$ja textureOptions = _Translations$readerSettings$textureOptions$ja._(_root);
}

// Path: reader
class _Translations$reader$ja extends Translations$reader$en {
	_Translations$reader$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get loading => '読み込み中...';
	@override String get loadingBook => '本を読み込み中...';
	@override String get search => '検索';
}

// Path: readerBar
class _Translations$readerBar$ja extends Translations$readerBar$en {
	_Translations$readerBar$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => '前の章';
	@override String get nextChapter => '次の章';
	@override String get pageNum => 'ページ';
}

// Path: readerSearch
class _Translations$readerSearch$ja extends Translations$readerSearch$en {
	_Translations$readerSearch$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get hint => '本を検索...';
	@override String get close => '閉じる';
	@override String get emptyPrompt => '検索語を入力してください。';
	@override String get noResults => '検索結果が見つかりませんでした。';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$ja extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get author => '著者：';
	@override String get read => '読む';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$ja extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '本を削除';
	@override String get message => '本棚から削除しますか？\nこの操作は元に戻せません。';
	@override String get cancel => 'キャンセル';
	@override String get delete => '削除';
	@override String get removeFromShelf => '本棚から削除';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$ja extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'インポート失敗';
	@override String get body => '本のインポートに失敗しました：';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$ja extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'ゴシック';
	@override String get myungjo => '明朝';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$ja extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'なめらか';
	@override String get standard => '標準';
	@override String get textured => 'ざらつき';
	@override String get kraft => 'クラフト';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsJa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => '本棚',
			'bookshelf.settings' => '本棚設定',
			'bookshelf.addBook' => '本を追加 (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => '本棚は空です',
			'bookshelf.emptyDescription' => '右上の + ボタンをタップするか、下のボタンを使用して\nEPUB、TXT、PDF ファイルを追加してください。',
			'bookshelf.importButton' => '本をインポート',
			'bookshelf.error' => 'エラーが発生しました：',
			'bookshelf.retry' => '再試行',
			'bookshelf.close' => '閉じる',
			'bookshelf.book.author' => '著者：',
			'bookshelf.book.read' => '読む',
			'bookshelf.deleteDialog.title' => '本を削除',
			'bookshelf.deleteDialog.message' => '本棚から削除しますか？\nこの操作は元に戻せません。',
			'bookshelf.deleteDialog.cancel' => 'キャンセル',
			'bookshelf.deleteDialog.delete' => '削除',
			'bookshelf.deleteDialog.removeFromShelf' => '本棚から削除',
			'bookshelf.importFailed.title' => 'インポート失敗',
			'bookshelf.importFailed.body' => '本のインポートに失敗しました：',
			'settingsPanel.title' => '本棚設定',
			'settingsPanel.cloudSync' => 'クラウド同期',
			'settingsPanel.syncStatus' => '同期ステータス',
			'settingsPanel.syncNow' => '今すぐ同期',
			'settingsPanel.appInfo' => 'アプリケーション情報',
			'settingsPanel.version' => 'バージョン',
			'settingsPanel.engine' => 'エンジン',
			'settingsPanel.status' => 'ステータス',
			'settingsPanel.darkMode' => 'ダークモード有効',
			'settingsPanel.done' => '完了',
			'settingsPanel.syncWaiting' => '待機中',
			'settingsPanel.syncVerifying' => '確認中...',
			'settingsPanel.syncing' => '同期中...',
			'settingsPanel.syncCompleted' => '同期完了',
			'settingsPanel.syncError' => '同期エラー',
			'readerSettings.title' => '読書設定',
			'readerSettings.fontSize' => 'フォントサイズ',
			'readerSettings.lineSpacing' => '行間',
			'readerSettings.brightness' => '明るさ',
			'readerSettings.font' => 'フォント',
			'readerSettings.haptics' => '触覚フィードバック',
			'readerSettings.texture' => '紙の質感',
			'readerSettings.sound' => '効果音',
			'readerSettings.done' => '完了',
			'readerSettings.fontOptions.gothic' => 'ゴシック',
			'readerSettings.fontOptions.myungjo' => '明朝',
			'readerSettings.textureOptions.smooth' => 'なめらか',
			'readerSettings.textureOptions.standard' => '標準',
			'readerSettings.textureOptions.textured' => 'ざらつき',
			'readerSettings.textureOptions.kraft' => 'クラフト',
			'reader.loading' => '読み込み中...',
			'reader.loadingBook' => '本を読み込み中...',
			'reader.search' => '検索',
			'readerBar.prevChapter' => '前の章',
			'readerBar.nextChapter' => '次の章',
			'readerBar.pageNum' => 'ページ',
			'readerSearch.hint' => '本を検索...',
			'readerSearch.close' => '閉じる',
			'readerSearch.emptyPrompt' => '検索語を入力してください。',
			'readerSearch.noResults' => '検索結果が見つかりませんでした。',
			_ => null,
		};
	}
}
