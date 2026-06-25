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
class TranslationsFr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fr>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsFr _root = this; // ignore: unused_field

	@override 
	TranslationsFr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$fr app = _Translations$app$fr._(_root);
	@override late final _Translations$bookshelf$fr bookshelf = _Translations$bookshelf$fr._(_root);
	@override late final _Translations$settingsPanel$fr settingsPanel = _Translations$settingsPanel$fr._(_root);
	@override late final _Translations$readerSettings$fr readerSettings = _Translations$readerSettings$fr._(_root);
	@override late final _Translations$reader$fr reader = _Translations$reader$fr._(_root);
	@override late final _Translations$readerBar$fr readerBar = _Translations$readerBar$fr._(_root);
	@override late final _Translations$readerSearch$fr readerSearch = _Translations$readerSearch$fr._(_root);
}

// Path: app
class _Translations$app$fr extends Translations$app$en {
	_Translations$app$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$fr extends Translations$bookshelf$en {
	_Translations$bookshelf$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bibliothèque';
	@override String get settings => 'Paramètres de la Bibliothèque';
	@override String get addBook => 'Ajouter un Livre (EPUB, TXT, PDF)';
	@override String get emptyTitle => 'Votre bibliothèque est vide';
	@override String get emptyDescription => 'Appuyez sur le bouton + en haut à droite ou utilisez\nle bouton ci-dessous pour ajouter des fichiers EPUB, TXT ou PDF.';
	@override String get importButton => 'Importer des Livres';
	@override String get error => 'Une erreur est survenue :';
	@override String get retry => 'Réessayer';
	@override String get close => 'Fermer';
	@override late final _Translations$bookshelf$book$fr book = _Translations$bookshelf$book$fr._(_root);
	@override late final _Translations$bookshelf$deleteDialog$fr deleteDialog = _Translations$bookshelf$deleteDialog$fr._(_root);
	@override late final _Translations$bookshelf$importFailed$fr importFailed = _Translations$bookshelf$importFailed$fr._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$fr extends Translations$settingsPanel$en {
	_Translations$settingsPanel$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Paramètres de la Bibliothèque';
	@override String get cloudSync => 'Synchronisation Cloud';
	@override String get syncStatus => 'État de la Synchronisation';
	@override String get syncNow => 'Synchroniser Maintenant';
	@override String get appInfo => 'Informations de l\'Application';
	@override String get version => 'Version';
	@override String get engine => 'Moteur';
	@override String get status => 'État';
	@override String get darkMode => 'Mode Sombre Activé';
	@override String get done => 'Terminé';
	@override String get syncWaiting => 'En attente';
	@override String get syncVerifying => 'Vérification...';
	@override String get syncing => 'Synchronisation...';
	@override String get syncCompleted => 'Synchronisation Terminée';
	@override String get syncError => 'Erreur de Synchronisation';
}

// Path: readerSettings
class _Translations$readerSettings$fr extends Translations$readerSettings$en {
	_Translations$readerSettings$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Paramètres de Lecture';
	@override String get fontSize => 'Taille de la Police';
	@override String get lineSpacing => 'Interligne';
	@override String get brightness => 'Luminosité';
	@override String get font => 'Police';
	@override String get haptics => 'Retour Haptique';
	@override String get texture => 'Texture du Papier';
	@override String get sound => 'Effets Sonores';
	@override String get done => 'Terminé';
	@override late final _Translations$readerSettings$fontOptions$fr fontOptions = _Translations$readerSettings$fontOptions$fr._(_root);
	@override late final _Translations$readerSettings$textureOptions$fr textureOptions = _Translations$readerSettings$textureOptions$fr._(_root);
}

// Path: reader
class _Translations$reader$fr extends Translations$reader$en {
	_Translations$reader$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Chargement...';
	@override String get loadingBook => 'Chargement du livre...';
	@override String get search => 'Rechercher';
}

// Path: readerBar
class _Translations$readerBar$fr extends Translations$readerBar$en {
	_Translations$readerBar$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => 'Chapitre Précédent';
	@override String get nextChapter => 'Chapitre Suivant';
	@override String get pageNum => 'Page';
}

// Path: readerSearch
class _Translations$readerSearch$fr extends Translations$readerSearch$en {
	_Translations$readerSearch$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Rechercher dans le livre...';
	@override String get close => 'Fermer';
	@override String get emptyPrompt => 'Saisissez un terme de recherche.';
	@override String get noResults => 'Aucun résultat trouvé.';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$fr extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get author => 'Auteur :';
	@override String get read => 'Lire';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$fr extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Supprimer le Livre';
	@override String get message => 'Supprimer de votre bibliothèque ?\nCette action est irréversible.';
	@override String get cancel => 'Annuler';
	@override String get delete => 'Supprimer';
	@override String get removeFromShelf => 'Retirer de la Bibliothèque';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$fr extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Échec de l\'Importation';
	@override String get body => 'Échec de l\'importation du livre :';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$fr extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'Gothique';
	@override String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$fr extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'Lisse';
	@override String get standard => 'Standard';
	@override String get textured => 'Texturé';
	@override String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <fr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Bibliothèque',
			'bookshelf.settings' => 'Paramètres de la Bibliothèque',
			'bookshelf.addBook' => 'Ajouter un Livre (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Votre bibliothèque est vide',
			'bookshelf.emptyDescription' => 'Appuyez sur le bouton + en haut à droite ou utilisez\nle bouton ci-dessous pour ajouter des fichiers EPUB, TXT ou PDF.',
			'bookshelf.importButton' => 'Importer des Livres',
			'bookshelf.error' => 'Une erreur est survenue :',
			'bookshelf.retry' => 'Réessayer',
			'bookshelf.close' => 'Fermer',
			'bookshelf.book.author' => 'Auteur :',
			'bookshelf.book.read' => 'Lire',
			'bookshelf.deleteDialog.title' => 'Supprimer le Livre',
			'bookshelf.deleteDialog.message' => 'Supprimer de votre bibliothèque ?\nCette action est irréversible.',
			'bookshelf.deleteDialog.cancel' => 'Annuler',
			'bookshelf.deleteDialog.delete' => 'Supprimer',
			'bookshelf.deleteDialog.removeFromShelf' => 'Retirer de la Bibliothèque',
			'bookshelf.importFailed.title' => 'Échec de l\'Importation',
			'bookshelf.importFailed.body' => 'Échec de l\'importation du livre :',
			'settingsPanel.title' => 'Paramètres de la Bibliothèque',
			'settingsPanel.cloudSync' => 'Synchronisation Cloud',
			'settingsPanel.syncStatus' => 'État de la Synchronisation',
			'settingsPanel.syncNow' => 'Synchroniser Maintenant',
			'settingsPanel.appInfo' => 'Informations de l\'Application',
			'settingsPanel.version' => 'Version',
			'settingsPanel.engine' => 'Moteur',
			'settingsPanel.status' => 'État',
			'settingsPanel.darkMode' => 'Mode Sombre Activé',
			'settingsPanel.done' => 'Terminé',
			'settingsPanel.syncWaiting' => 'En attente',
			'settingsPanel.syncVerifying' => 'Vérification...',
			'settingsPanel.syncing' => 'Synchronisation...',
			'settingsPanel.syncCompleted' => 'Synchronisation Terminée',
			'settingsPanel.syncError' => 'Erreur de Synchronisation',
			'readerSettings.title' => 'Paramètres de Lecture',
			'readerSettings.fontSize' => 'Taille de la Police',
			'readerSettings.lineSpacing' => 'Interligne',
			'readerSettings.brightness' => 'Luminosité',
			'readerSettings.font' => 'Police',
			'readerSettings.haptics' => 'Retour Haptique',
			'readerSettings.texture' => 'Texture du Papier',
			'readerSettings.sound' => 'Effets Sonores',
			'readerSettings.done' => 'Terminé',
			'readerSettings.fontOptions.gothic' => 'Gothique',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Lisse',
			'readerSettings.textureOptions.standard' => 'Standard',
			'readerSettings.textureOptions.textured' => 'Texturé',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Chargement...',
			'reader.loadingBook' => 'Chargement du livre...',
			'reader.search' => 'Rechercher',
			'readerBar.prevChapter' => 'Chapitre Précédent',
			'readerBar.nextChapter' => 'Chapitre Suivant',
			'readerBar.pageNum' => 'Page',
			'readerSearch.hint' => 'Rechercher dans le livre...',
			'readerSearch.close' => 'Fermer',
			'readerSearch.emptyPrompt' => 'Saisissez un terme de recherche.',
			'readerSearch.noResults' => 'Aucun résultat trouvé.',
			_ => null,
		};
	}
}
