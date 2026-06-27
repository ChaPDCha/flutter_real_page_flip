///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'translations.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	dynamic operator[](String key) => $meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$en app = Translations$app$en.internal(_root);
	late final Translations$bookshelf$en bookshelf = Translations$bookshelf$en.internal(_root);
	late final Translations$settingsPanel$en settingsPanel = Translations$settingsPanel$en.internal(_root);
	late final Translations$readerSettings$en readerSettings = Translations$readerSettings$en.internal(_root);
	late final Translations$reader$en reader = Translations$reader$en.internal(_root);
	late final Translations$readerBar$en readerBar = Translations$readerBar$en.internal(_root);
	late final Translations$readerSearch$en readerSearch = Translations$readerSearch$en.internal(_root);
}

// Path: app
class Translations$app$en {
	Translations$app$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Realbook Reader'
	String get title => 'Realbook Reader';
}

// Path: bookshelf
class Translations$bookshelf$en {
	Translations$bookshelf$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Bookshelf'
	String get title => 'Bookshelf';

	/// en: 'Shelf Settings'
	String get settings => 'Shelf Settings';

	/// en: 'Add Book (EPUB, TXT, PDF)'
	String get addBook => 'Add Book (EPUB, TXT, PDF)';

	/// en: 'Your shelf is empty'
	String get emptyTitle => 'Your shelf is empty';

	/// en: 'Tap the + button in the top right, or use the button below to add your EPUB, TXT, or PDF files.'
	String get emptyDescription => 'Tap the + button in the top right, or use the button below\nto add your EPUB, TXT, or PDF files.';

	/// en: 'Import Books'
	String get importButton => 'Import Books';

	/// en: 'An error occurred:'
	String get error => 'An error occurred:';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Close'
	String get close => 'Close';

	late final Translations$bookshelf$book$en book = Translations$bookshelf$book$en.internal(_root);
	late final Translations$bookshelf$deleteDialog$en deleteDialog = Translations$bookshelf$deleteDialog$en.internal(_root);
	late final Translations$bookshelf$importFailed$en importFailed = Translations$bookshelf$importFailed$en.internal(_root);
}

// Path: settingsPanel
class Translations$settingsPanel$en {
	Translations$settingsPanel$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Shelf Settings'
	String get title => 'Shelf Settings';

	/// en: 'Cloud Sync'
	String get cloudSync => 'Cloud Sync';

	/// en: 'Sync Status'
	String get syncStatus => 'Sync Status';

	/// en: 'Sync Now'
	String get syncNow => 'Sync Now';

	/// en: 'Application Info'
	String get appInfo => 'Application Info';

	/// en: 'Version'
	String get version => 'Version';

	/// en: 'Engine'
	String get engine => 'Engine';

	/// en: 'Status'
	String get status => 'Status';

	/// en: 'Dark Mode Enabled'
	String get darkMode => 'Dark Mode Enabled';

	/// en: 'Done'
	String get done => 'Done';

	/// en: 'Waiting'
	String get syncWaiting => 'Waiting';

	/// en: 'Verifying...'
	String get syncVerifying => 'Verifying...';

	/// en: 'Syncing...'
	String get syncing => 'Syncing...';

	/// en: 'Sync Complete'
	String get syncCompleted => 'Sync Complete';

	/// en: 'Sync Error'
	String get syncError => 'Sync Error';
}

// Path: readerSettings
class Translations$readerSettings$en {
	Translations$readerSettings$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Reading Settings'
	String get title => 'Reading Settings';

	/// en: 'Font Size'
	String get fontSize => 'Font Size';

	/// en: 'Line Spacing'
	String get lineSpacing => 'Line Spacing';

	/// en: 'Brightness'
	String get brightness => 'Brightness';

	/// en: 'Font'
	String get font => 'Font';

	/// en: 'Haptic Feedback'
	String get haptics => 'Haptic Feedback';

	/// en: 'Paper Texture'
	String get texture => 'Paper Texture';

	/// en: 'Sound Effects'
	String get sound => 'Sound Effects';

	/// en: 'Done'
	String get done => 'Done';

	late final Translations$readerSettings$fontOptions$en fontOptions = Translations$readerSettings$fontOptions$en.internal(_root);
	late final Translations$readerSettings$textureOptions$en textureOptions = Translations$readerSettings$textureOptions$en.internal(_root);
}

// Path: reader
class Translations$reader$en {
	Translations$reader$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Loading...'
	String get loading => 'Loading...';

	/// en: 'Loading book...'
	String get loadingBook => 'Loading book...';

	/// en: 'Search'
	String get search => 'Search';
}

// Path: readerBar
class Translations$readerBar$en {
	Translations$readerBar$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Previous Chapter'
	String get prevChapter => 'Previous Chapter';

	/// en: 'Next Chapter'
	String get nextChapter => 'Next Chapter';

	/// en: 'Page'
	String get pageNum => 'Page';
}

// Path: readerSearch
class Translations$readerSearch$en {
	Translations$readerSearch$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Search in book...'
	String get hint => 'Search in book...';

	/// en: 'Close'
	String get close => 'Close';

	/// en: 'Enter a search term to begin.'
	String get emptyPrompt => 'Enter a search term to begin.';

	/// en: 'No results found.'
	String get noResults => 'No results found.';
}

// Path: bookshelf.book
class Translations$bookshelf$book$en {
	Translations$bookshelf$book$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Author:'
	String get author => 'Author:';

	/// en: 'Read'
	String get read => 'Read';
}

// Path: bookshelf.deleteDialog
class Translations$bookshelf$deleteDialog$en {
	Translations$bookshelf$deleteDialog$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Delete Book'
	String get title => 'Delete Book';

	/// en: 'Remove from your shelf? This action cannot be undone.'
	String get message => 'Remove from your shelf?\nThis action cannot be undone.';

	/// en: 'Cancel'
	String get cancel => 'Cancel';

	/// en: 'Delete'
	String get delete => 'Delete';

	/// en: 'Remove from Shelf'
	String get removeFromShelf => 'Remove from Shelf';
}

// Path: bookshelf.importFailed
class Translations$bookshelf$importFailed$en {
	Translations$bookshelf$importFailed$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Import Failed'
	String get title => 'Import Failed';

	/// en: 'Failed to import book:'
	String get body => 'Failed to import book:';
}

// Path: readerSettings.fontOptions
class Translations$readerSettings$fontOptions$en {
	Translations$readerSettings$fontOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Gothic'
	String get gothic => 'Gothic';

	/// en: 'Myungjo'
	String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class Translations$readerSettings$textureOptions$en {
	Translations$readerSettings$textureOptions$en.internal(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Smooth'
	String get smooth => 'Smooth';

	/// en: 'Standard'
	String get standard => 'Standard';

	/// en: 'Textured'
	String get textured => 'Textured';

	/// en: 'Kraft'
	String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Bookshelf',
			'bookshelf.settings' => 'Shelf Settings',
			'bookshelf.addBook' => 'Add Book (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Your shelf is empty',
			'bookshelf.emptyDescription' => 'Tap the + button in the top right, or use the button below\nto add your EPUB, TXT, or PDF files.',
			'bookshelf.importButton' => 'Import Books',
			'bookshelf.error' => 'An error occurred:',
			'bookshelf.retry' => 'Retry',
			'bookshelf.close' => 'Close',
			'bookshelf.book.author' => 'Author:',
			'bookshelf.book.read' => 'Read',
			'bookshelf.deleteDialog.title' => 'Delete Book',
			'bookshelf.deleteDialog.message' => 'Remove from your shelf?\nThis action cannot be undone.',
			'bookshelf.deleteDialog.cancel' => 'Cancel',
			'bookshelf.deleteDialog.delete' => 'Delete',
			'bookshelf.deleteDialog.removeFromShelf' => 'Remove from Shelf',
			'bookshelf.importFailed.title' => 'Import Failed',
			'bookshelf.importFailed.body' => 'Failed to import book:',
			'settingsPanel.title' => 'Shelf Settings',
			'settingsPanel.cloudSync' => 'Cloud Sync',
			'settingsPanel.syncStatus' => 'Sync Status',
			'settingsPanel.syncNow' => 'Sync Now',
			'settingsPanel.appInfo' => 'Application Info',
			'settingsPanel.version' => 'Version',
			'settingsPanel.engine' => 'Engine',
			'settingsPanel.status' => 'Status',
			'settingsPanel.darkMode' => 'Dark Mode Enabled',
			'settingsPanel.done' => 'Done',
			'settingsPanel.syncWaiting' => 'Waiting',
			'settingsPanel.syncVerifying' => 'Verifying...',
			'settingsPanel.syncing' => 'Syncing...',
			'settingsPanel.syncCompleted' => 'Sync Complete',
			'settingsPanel.syncError' => 'Sync Error',
			'readerSettings.title' => 'Reading Settings',
			'readerSettings.fontSize' => 'Font Size',
			'readerSettings.lineSpacing' => 'Line Spacing',
			'readerSettings.brightness' => 'Brightness',
			'readerSettings.font' => 'Font',
			'readerSettings.haptics' => 'Haptic Feedback',
			'readerSettings.texture' => 'Paper Texture',
			'readerSettings.sound' => 'Sound Effects',
			'readerSettings.done' => 'Done',
			'readerSettings.fontOptions.gothic' => 'Gothic',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Smooth',
			'readerSettings.textureOptions.standard' => 'Standard',
			'readerSettings.textureOptions.textured' => 'Textured',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Loading...',
			'reader.loadingBook' => 'Loading book...',
			'reader.search' => 'Search',
			'readerBar.prevChapter' => 'Previous Chapter',
			'readerBar.nextChapter' => 'Next Chapter',
			'readerBar.pageNum' => 'Page',
			'readerSearch.hint' => 'Search in book...',
			'readerSearch.close' => 'Close',
			'readerSearch.emptyPrompt' => 'Enter a search term to begin.',
			'readerSearch.noResults' => 'No results found.',
			_ => null,
		};
	}
}
