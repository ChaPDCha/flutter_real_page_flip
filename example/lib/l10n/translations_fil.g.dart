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
class TranslationsFil extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFil({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fil,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fil>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsFil _root = this; // ignore: unused_field

	@override 
	TranslationsFil $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFil(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$fil app = _Translations$app$fil._(_root);
	@override late final _Translations$bookshelf$fil bookshelf = _Translations$bookshelf$fil._(_root);
	@override late final _Translations$settingsPanel$fil settingsPanel = _Translations$settingsPanel$fil._(_root);
	@override late final _Translations$readerSettings$fil readerSettings = _Translations$readerSettings$fil._(_root);
	@override late final _Translations$reader$fil reader = _Translations$reader$fil._(_root);
	@override late final _Translations$readerBar$fil readerBar = _Translations$readerBar$fil._(_root);
	@override late final _Translations$readerSearch$fil readerSearch = _Translations$readerSearch$fil._(_root);
}

// Path: app
class _Translations$app$fil extends Translations$app$en {
	_Translations$app$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$fil extends Translations$bookshelf$en {
	_Translations$bookshelf$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estante ng Aklat';
	@override String get settings => 'Settings ng Estante';
	@override String get addBook => 'Magdagdag ng Aklat (EPUB, TXT, PDF)';
	@override String get emptyTitle => 'Walang laman ang iyong estante';
	@override String get emptyDescription => 'Pindutin ang + button sa kanang itaas o gamitin ang\nbutton sa ibaba upang magdagdag ng EPUB, TXT, o PDF.';
	@override String get importButton => 'Mag-import ng Aklat';
	@override String get error => 'May naganap na error:';
	@override String get retry => 'Subukan Muli';
	@override String get close => 'Isara';
	@override late final _Translations$bookshelf$book$fil book = _Translations$bookshelf$book$fil._(_root);
	@override late final _Translations$bookshelf$deleteDialog$fil deleteDialog = _Translations$bookshelf$deleteDialog$fil._(_root);
	@override late final _Translations$bookshelf$importFailed$fil importFailed = _Translations$bookshelf$importFailed$fil._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$fil extends Translations$settingsPanel$en {
	_Translations$settingsPanel$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings ng Estante';
	@override String get cloudSync => 'Cloud Sync';
	@override String get syncStatus => 'Status ng Sync';
	@override String get syncNow => 'I-sync Ngayon';
	@override String get appInfo => 'Impormasyon ng App';
	@override String get version => 'Bersyon';
	@override String get engine => 'Engine';
	@override String get status => 'Status';
	@override String get darkMode => 'Dark Mode Naka-activate';
	@override String get done => 'Tapos';
	@override String get syncWaiting => 'Naghihintay';
	@override String get syncVerifying => 'Bine-beripika...';
	@override String get syncing => 'Sini-sync...';
	@override String get syncCompleted => 'Kumpleto ang Sync';
	@override String get syncError => 'Error sa Sync';
}

// Path: readerSettings
class _Translations$readerSettings$fil extends Translations$readerSettings$en {
	_Translations$readerSettings$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Settings sa Pagbasa';
	@override String get fontSize => 'Laki ng Letra';
	@override String get lineSpacing => 'Espasyo ng Linya';
	@override String get brightness => 'Liwanag';
	@override String get font => 'Font';
	@override String get haptics => 'Haptic Feedback';
	@override String get texture => 'Texture ng Papel';
	@override String get sound => 'Epekto ng Tunog';
	@override String get done => 'Tapos';
	@override late final _Translations$readerSettings$fontOptions$fil fontOptions = _Translations$readerSettings$fontOptions$fil._(_root);
	@override late final _Translations$readerSettings$textureOptions$fil textureOptions = _Translations$readerSettings$textureOptions$fil._(_root);
}

// Path: reader
class _Translations$reader$fil extends Translations$reader$en {
	_Translations$reader$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Naglo-load...';
	@override String get loadingBook => 'Naglo-load ng aklat...';
	@override String get search => 'Maghanap';
}

// Path: readerBar
class _Translations$readerBar$fil extends Translations$readerBar$en {
	_Translations$readerBar$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => 'Nakaraang Kabanata';
	@override String get nextChapter => 'Susunod na Kabanata';
	@override String get pageNum => 'Pahina';
}

// Path: readerSearch
class _Translations$readerSearch$fil extends Translations$readerSearch$en {
	_Translations$readerSearch$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Maghanap sa aklat...';
	@override String get close => 'Isara';
	@override String get emptyPrompt => 'Maglagay ng salitang hahanapin.';
	@override String get noResults => 'Walang nakitang resulta.';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$fil extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get author => 'May-akda:';
	@override String get read => 'Basahin';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$fil extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Burahin ang Aklat';
	@override String get message => 'Burahin mula sa iyong estante?\nHindi na ito maaaring ibalik.';
	@override String get cancel => 'Kanselahin';
	@override String get delete => 'Burahin';
	@override String get removeFromShelf => 'Alisin sa Estante';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$fil extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nabigo ang Pag-import';
	@override String get body => 'Nabigo ang pag-import ng aklat:';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$fil extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'Gothic';
	@override String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$fil extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$fil._(TranslationsFil root) : this._root = root, super.internal(root);

	final TranslationsFil _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'Makinis';
	@override String get standard => 'Karaniwan';
	@override String get textured => 'May Texture';
	@override String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <fil>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFil {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Estante ng Aklat',
			'bookshelf.settings' => 'Settings ng Estante',
			'bookshelf.addBook' => 'Magdagdag ng Aklat (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Walang laman ang iyong estante',
			'bookshelf.emptyDescription' => 'Pindutin ang + button sa kanang itaas o gamitin ang\nbutton sa ibaba upang magdagdag ng EPUB, TXT, o PDF.',
			'bookshelf.importButton' => 'Mag-import ng Aklat',
			'bookshelf.error' => 'May naganap na error:',
			'bookshelf.retry' => 'Subukan Muli',
			'bookshelf.close' => 'Isara',
			'bookshelf.book.author' => 'May-akda:',
			'bookshelf.book.read' => 'Basahin',
			'bookshelf.deleteDialog.title' => 'Burahin ang Aklat',
			'bookshelf.deleteDialog.message' => 'Burahin mula sa iyong estante?\nHindi na ito maaaring ibalik.',
			'bookshelf.deleteDialog.cancel' => 'Kanselahin',
			'bookshelf.deleteDialog.delete' => 'Burahin',
			'bookshelf.deleteDialog.removeFromShelf' => 'Alisin sa Estante',
			'bookshelf.importFailed.title' => 'Nabigo ang Pag-import',
			'bookshelf.importFailed.body' => 'Nabigo ang pag-import ng aklat:',
			'settingsPanel.title' => 'Settings ng Estante',
			'settingsPanel.cloudSync' => 'Cloud Sync',
			'settingsPanel.syncStatus' => 'Status ng Sync',
			'settingsPanel.syncNow' => 'I-sync Ngayon',
			'settingsPanel.appInfo' => 'Impormasyon ng App',
			'settingsPanel.version' => 'Bersyon',
			'settingsPanel.engine' => 'Engine',
			'settingsPanel.status' => 'Status',
			'settingsPanel.darkMode' => 'Dark Mode Naka-activate',
			'settingsPanel.done' => 'Tapos',
			'settingsPanel.syncWaiting' => 'Naghihintay',
			'settingsPanel.syncVerifying' => 'Bine-beripika...',
			'settingsPanel.syncing' => 'Sini-sync...',
			'settingsPanel.syncCompleted' => 'Kumpleto ang Sync',
			'settingsPanel.syncError' => 'Error sa Sync',
			'readerSettings.title' => 'Settings sa Pagbasa',
			'readerSettings.fontSize' => 'Laki ng Letra',
			'readerSettings.lineSpacing' => 'Espasyo ng Linya',
			'readerSettings.brightness' => 'Liwanag',
			'readerSettings.font' => 'Font',
			'readerSettings.haptics' => 'Haptic Feedback',
			'readerSettings.texture' => 'Texture ng Papel',
			'readerSettings.sound' => 'Epekto ng Tunog',
			'readerSettings.done' => 'Tapos',
			'readerSettings.fontOptions.gothic' => 'Gothic',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Makinis',
			'readerSettings.textureOptions.standard' => 'Karaniwan',
			'readerSettings.textureOptions.textured' => 'May Texture',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Naglo-load...',
			'reader.loadingBook' => 'Naglo-load ng aklat...',
			'reader.search' => 'Maghanap',
			'readerBar.prevChapter' => 'Nakaraang Kabanata',
			'readerBar.nextChapter' => 'Susunod na Kabanata',
			'readerBar.pageNum' => 'Pahina',
			'readerSearch.hint' => 'Maghanap sa aklat...',
			'readerSearch.close' => 'Isara',
			'readerSearch.emptyPrompt' => 'Maglagay ng salitang hahanapin.',
			'readerSearch.noResults' => 'Walang nakitang resulta.',
			_ => null,
		};
	}
}
