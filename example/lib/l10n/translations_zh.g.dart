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
class TranslationsZh extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZh({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsZh _root = this; // ignore: unused_field

	@override 
	TranslationsZh $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZh(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$zh app = _Translations$app$zh._(_root);
	@override late final _Translations$bookshelf$zh bookshelf = _Translations$bookshelf$zh._(_root);
	@override late final _Translations$settingsPanel$zh settingsPanel = _Translations$settingsPanel$zh._(_root);
	@override late final _Translations$readerSettings$zh readerSettings = _Translations$readerSettings$zh._(_root);
	@override late final _Translations$reader$zh reader = _Translations$reader$zh._(_root);
	@override late final _Translations$readerBar$zh readerBar = _Translations$readerBar$zh._(_root);
	@override late final _Translations$readerSearch$zh readerSearch = _Translations$readerSearch$zh._(_root);
}

// Path: app
class _Translations$app$zh extends Translations$app$en {
	_Translations$app$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$zh extends Translations$bookshelf$en {
	_Translations$bookshelf$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '书架';
	@override String get settings => '书架设置';
	@override String get addBook => '添加书籍 (EPUB, TXT, PDF)';
	@override String get emptyTitle => '您的书架是空的';
	@override String get emptyDescription => '点击右上角的 + 按钮，或使用下面的按钮\n添加 EPUB、TXT 或 PDF 文件。';
	@override String get importButton => '导入书籍';
	@override String get error => '发生错误：';
	@override String get retry => '重试';
	@override String get close => '关闭';
	@override late final _Translations$bookshelf$book$zh book = _Translations$bookshelf$book$zh._(_root);
	@override late final _Translations$bookshelf$deleteDialog$zh deleteDialog = _Translations$bookshelf$deleteDialog$zh._(_root);
	@override late final _Translations$bookshelf$importFailed$zh importFailed = _Translations$bookshelf$importFailed$zh._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$zh extends Translations$settingsPanel$en {
	_Translations$settingsPanel$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '书架设置';
	@override String get cloudSync => '云同步';
	@override String get syncStatus => '同步状态';
	@override String get syncNow => '立即同步';
	@override String get appInfo => '应用程序信息';
	@override String get version => '版本';
	@override String get engine => '引擎';
	@override String get status => '状态';
	@override String get darkMode => '深色模式已启用';
	@override String get done => '完成';
	@override String get syncWaiting => '等待中';
	@override String get syncVerifying => '验证中...';
	@override String get syncing => '同步中...';
	@override String get syncCompleted => '同步完成';
	@override String get syncError => '同步错误';
}

// Path: readerSettings
class _Translations$readerSettings$zh extends Translations$readerSettings$en {
	_Translations$readerSettings$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '阅读设置';
	@override String get fontSize => '字体大小';
	@override String get lineSpacing => '行间距';
	@override String get brightness => '亮度';
	@override String get font => '字体';
	@override String get haptics => '触觉反馈';
	@override String get texture => '纸张纹理';
	@override String get sound => '音效';
	@override String get done => '完成';
	@override late final _Translations$readerSettings$fontOptions$zh fontOptions = _Translations$readerSettings$fontOptions$zh._(_root);
	@override late final _Translations$readerSettings$textureOptions$zh textureOptions = _Translations$readerSettings$textureOptions$zh._(_root);
}

// Path: reader
class _Translations$reader$zh extends Translations$reader$en {
	_Translations$reader$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get loading => '加载中...';
	@override String get loadingBook => '正在加载书籍...';
	@override String get search => '搜索';
}

// Path: readerBar
class _Translations$readerBar$zh extends Translations$readerBar$en {
	_Translations$readerBar$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => '上一章';
	@override String get nextChapter => '下一章';
	@override String get pageNum => '页';
}

// Path: readerSearch
class _Translations$readerSearch$zh extends Translations$readerSearch$en {
	_Translations$readerSearch$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get hint => '搜索书籍内容...';
	@override String get close => '关闭';
	@override String get emptyPrompt => '输入搜索词开始搜索。';
	@override String get noResults => '未找到搜索结果。';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$zh extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get author => '作者：';
	@override String get read => '阅读';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$zh extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '删除书籍';
	@override String get message => '从书架中删除吗？\n此操作无法撤销。';
	@override String get cancel => '取消';
	@override String get delete => '删除';
	@override String get removeFromShelf => '从书架中移除';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$zh extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '导入失败';
	@override String get body => '导入书籍失败：';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$zh extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get gothic => '哥特体';
	@override String get myungjo => '明朝体';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$zh extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get smooth => '光滑';
	@override String get standard => '标准';
	@override String get textured => '粗糙';
	@override String get kraft => '牛皮纸';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZh {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => '书架',
			'bookshelf.settings' => '书架设置',
			'bookshelf.addBook' => '添加书籍 (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => '您的书架是空的',
			'bookshelf.emptyDescription' => '点击右上角的 + 按钮，或使用下面的按钮\n添加 EPUB、TXT 或 PDF 文件。',
			'bookshelf.importButton' => '导入书籍',
			'bookshelf.error' => '发生错误：',
			'bookshelf.retry' => '重试',
			'bookshelf.close' => '关闭',
			'bookshelf.book.author' => '作者：',
			'bookshelf.book.read' => '阅读',
			'bookshelf.deleteDialog.title' => '删除书籍',
			'bookshelf.deleteDialog.message' => '从书架中删除吗？\n此操作无法撤销。',
			'bookshelf.deleteDialog.cancel' => '取消',
			'bookshelf.deleteDialog.delete' => '删除',
			'bookshelf.deleteDialog.removeFromShelf' => '从书架中移除',
			'bookshelf.importFailed.title' => '导入失败',
			'bookshelf.importFailed.body' => '导入书籍失败：',
			'settingsPanel.title' => '书架设置',
			'settingsPanel.cloudSync' => '云同步',
			'settingsPanel.syncStatus' => '同步状态',
			'settingsPanel.syncNow' => '立即同步',
			'settingsPanel.appInfo' => '应用程序信息',
			'settingsPanel.version' => '版本',
			'settingsPanel.engine' => '引擎',
			'settingsPanel.status' => '状态',
			'settingsPanel.darkMode' => '深色模式已启用',
			'settingsPanel.done' => '完成',
			'settingsPanel.syncWaiting' => '等待中',
			'settingsPanel.syncVerifying' => '验证中...',
			'settingsPanel.syncing' => '同步中...',
			'settingsPanel.syncCompleted' => '同步完成',
			'settingsPanel.syncError' => '同步错误',
			'readerSettings.title' => '阅读设置',
			'readerSettings.fontSize' => '字体大小',
			'readerSettings.lineSpacing' => '行间距',
			'readerSettings.brightness' => '亮度',
			'readerSettings.font' => '字体',
			'readerSettings.haptics' => '触觉反馈',
			'readerSettings.texture' => '纸张纹理',
			'readerSettings.sound' => '音效',
			'readerSettings.done' => '完成',
			'readerSettings.fontOptions.gothic' => '哥特体',
			'readerSettings.fontOptions.myungjo' => '明朝体',
			'readerSettings.textureOptions.smooth' => '光滑',
			'readerSettings.textureOptions.standard' => '标准',
			'readerSettings.textureOptions.textured' => '粗糙',
			'readerSettings.textureOptions.kraft' => '牛皮纸',
			'reader.loading' => '加载中...',
			'reader.loadingBook' => '正在加载书籍...',
			'reader.search' => '搜索',
			'readerBar.prevChapter' => '上一章',
			'readerBar.nextChapter' => '下一章',
			'readerBar.pageNum' => '页',
			'readerSearch.hint' => '搜索书籍内容...',
			'readerSearch.close' => '关闭',
			'readerSearch.emptyPrompt' => '输入搜索词开始搜索。',
			'readerSearch.noResults' => '未找到搜索结果。',
			_ => null,
		};
	}
}
