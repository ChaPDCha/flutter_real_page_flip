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
class TranslationsEs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.es,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <es>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsEs _root = this; // ignore: unused_field

	@override 
	TranslationsEs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$es app = _Translations$app$es._(_root);
	@override late final _Translations$bookshelf$es bookshelf = _Translations$bookshelf$es._(_root);
	@override late final _Translations$settingsPanel$es settingsPanel = _Translations$settingsPanel$es._(_root);
	@override late final _Translations$readerSettings$es readerSettings = _Translations$readerSettings$es._(_root);
	@override late final _Translations$reader$es reader = _Translations$reader$es._(_root);
	@override late final _Translations$readerBar$es readerBar = _Translations$readerBar$es._(_root);
	@override late final _Translations$readerSearch$es readerSearch = _Translations$readerSearch$es._(_root);
}

// Path: app
class _Translations$app$es extends Translations$app$en {
	_Translations$app$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$es extends Translations$bookshelf$en {
	_Translations$bookshelf$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Biblioteca';
	@override String get settings => 'Ajustes de Biblioteca';
	@override String get addBook => 'Agregar Libro (EPUB, TXT, PDF)';
	@override String get emptyTitle => 'Tu biblioteca está vacía';
	@override String get emptyDescription => 'Toca el botón + en la esquina superior derecha o usa el botón\nde abajo para agregar archivos EPUB, TXT o PDF.';
	@override String get importButton => 'Importar Libros';
	@override String get error => 'Ocurrió un error:';
	@override String get retry => 'Reintentar';
	@override String get close => 'Cerrar';
	@override late final _Translations$bookshelf$book$es book = _Translations$bookshelf$book$es._(_root);
	@override late final _Translations$bookshelf$deleteDialog$es deleteDialog = _Translations$bookshelf$deleteDialog$es._(_root);
	@override late final _Translations$bookshelf$importFailed$es importFailed = _Translations$bookshelf$importFailed$es._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$es extends Translations$settingsPanel$en {
	_Translations$settingsPanel$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajustes de Biblioteca';
	@override String get cloudSync => 'Sincronización en la Nube';
	@override String get syncStatus => 'Estado de Sincronización';
	@override String get syncNow => 'Sincronizar Ahora';
	@override String get appInfo => 'Información de la Aplicación';
	@override String get version => 'Versión';
	@override String get engine => 'Motor';
	@override String get status => 'Estado';
	@override String get darkMode => 'Modo Oscuro Activado';
	@override String get done => 'Hecho';
	@override String get syncWaiting => 'Esperando';
	@override String get syncVerifying => 'Verificando...';
	@override String get syncing => 'Sincronizando...';
	@override String get syncCompleted => 'Sincronización Completa';
	@override String get syncError => 'Error de Sincronización';
}

// Path: readerSettings
class _Translations$readerSettings$es extends Translations$readerSettings$en {
	_Translations$readerSettings$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajustes de Lectura';
	@override String get fontSize => 'Tamaño de Letra';
	@override String get lineSpacing => 'Espaciado';
	@override String get brightness => 'Brillo';
	@override String get font => 'Fuente';
	@override String get haptics => 'Retroalimentación Háptica';
	@override String get texture => 'Textura de Papel';
	@override String get sound => 'Efectos de Sonido';
	@override String get done => 'Hecho';
	@override late final _Translations$readerSettings$fontOptions$es fontOptions = _Translations$readerSettings$fontOptions$es._(_root);
	@override late final _Translations$readerSettings$textureOptions$es textureOptions = _Translations$readerSettings$textureOptions$es._(_root);
}

// Path: reader
class _Translations$reader$es extends Translations$reader$en {
	_Translations$reader$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Cargando...';
	@override String get loadingBook => 'Cargando libro...';
	@override String get search => 'Buscar';
}

// Path: readerBar
class _Translations$readerBar$es extends Translations$readerBar$en {
	_Translations$readerBar$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => 'Capítulo Anterior';
	@override String get nextChapter => 'Capítulo Siguiente';
	@override String get pageNum => 'Página';
}

// Path: readerSearch
class _Translations$readerSearch$es extends Translations$readerSearch$en {
	_Translations$readerSearch$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Buscar en el libro...';
	@override String get close => 'Cerrar';
	@override String get emptyPrompt => 'Ingresa un término de búsqueda.';
	@override String get noResults => 'No se encontraron resultados.';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$es extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get author => 'Autor:';
	@override String get read => 'Leer';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$es extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Eliminar Libro';
	@override String get message => 'Eliminar de tu biblioteca?\nEsta acción no se puede deshacer.';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Eliminar';
	@override String get removeFromShelf => 'Eliminar de la Biblioteca';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$es extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importación Fallida';
	@override String get body => 'Error al importar el libro:';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$es extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'Gótica';
	@override String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$es extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$es._(TranslationsEs root) : this._root = root, super.internal(root);

	final TranslationsEs _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'Suave';
	@override String get standard => 'Estándar';
	@override String get textured => 'Texturada';
	@override String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <es>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Biblioteca',
			'bookshelf.settings' => 'Ajustes de Biblioteca',
			'bookshelf.addBook' => 'Agregar Libro (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Tu biblioteca está vacía',
			'bookshelf.emptyDescription' => 'Toca el botón + en la esquina superior derecha o usa el botón\nde abajo para agregar archivos EPUB, TXT o PDF.',
			'bookshelf.importButton' => 'Importar Libros',
			'bookshelf.error' => 'Ocurrió un error:',
			'bookshelf.retry' => 'Reintentar',
			'bookshelf.close' => 'Cerrar',
			'bookshelf.book.author' => 'Autor:',
			'bookshelf.book.read' => 'Leer',
			'bookshelf.deleteDialog.title' => 'Eliminar Libro',
			'bookshelf.deleteDialog.message' => 'Eliminar de tu biblioteca?\nEsta acción no se puede deshacer.',
			'bookshelf.deleteDialog.cancel' => 'Cancelar',
			'bookshelf.deleteDialog.delete' => 'Eliminar',
			'bookshelf.deleteDialog.removeFromShelf' => 'Eliminar de la Biblioteca',
			'bookshelf.importFailed.title' => 'Importación Fallida',
			'bookshelf.importFailed.body' => 'Error al importar el libro:',
			'settingsPanel.title' => 'Ajustes de Biblioteca',
			'settingsPanel.cloudSync' => 'Sincronización en la Nube',
			'settingsPanel.syncStatus' => 'Estado de Sincronización',
			'settingsPanel.syncNow' => 'Sincronizar Ahora',
			'settingsPanel.appInfo' => 'Información de la Aplicación',
			'settingsPanel.version' => 'Versión',
			'settingsPanel.engine' => 'Motor',
			'settingsPanel.status' => 'Estado',
			'settingsPanel.darkMode' => 'Modo Oscuro Activado',
			'settingsPanel.done' => 'Hecho',
			'settingsPanel.syncWaiting' => 'Esperando',
			'settingsPanel.syncVerifying' => 'Verificando...',
			'settingsPanel.syncing' => 'Sincronizando...',
			'settingsPanel.syncCompleted' => 'Sincronización Completa',
			'settingsPanel.syncError' => 'Error de Sincronización',
			'readerSettings.title' => 'Ajustes de Lectura',
			'readerSettings.fontSize' => 'Tamaño de Letra',
			'readerSettings.lineSpacing' => 'Espaciado',
			'readerSettings.brightness' => 'Brillo',
			'readerSettings.font' => 'Fuente',
			'readerSettings.haptics' => 'Retroalimentación Háptica',
			'readerSettings.texture' => 'Textura de Papel',
			'readerSettings.sound' => 'Efectos de Sonido',
			'readerSettings.done' => 'Hecho',
			'readerSettings.fontOptions.gothic' => 'Gótica',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Suave',
			'readerSettings.textureOptions.standard' => 'Estándar',
			'readerSettings.textureOptions.textured' => 'Texturada',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Cargando...',
			'reader.loadingBook' => 'Cargando libro...',
			'reader.search' => 'Buscar',
			'readerBar.prevChapter' => 'Capítulo Anterior',
			'readerBar.nextChapter' => 'Capítulo Siguiente',
			'readerBar.pageNum' => 'Página',
			'readerSearch.hint' => 'Buscar en el libro...',
			'readerSearch.close' => 'Cerrar',
			'readerSearch.emptyPrompt' => 'Ingresa un término de búsqueda.',
			'readerSearch.noResults' => 'No se encontraron resultados.',
			_ => null,
		};
	}
}
