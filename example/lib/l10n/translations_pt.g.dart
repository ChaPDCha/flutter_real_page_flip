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
class TranslationsPt extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsPt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.pt,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsPt _root = this; // ignore: unused_field

	@override 
	TranslationsPt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsPt(meta: meta ?? this.$meta);

	// Translations
	@override late final Translations$app$pt app = Translations$app$pt.internal(_root);
	@override late final Translations$bookshelf$pt bookshelf = Translations$bookshelf$pt.internal(_root);
	@override late final Translations$settingsPanel$pt settingsPanel = Translations$settingsPanel$pt.internal(_root);
	@override late final Translations$readerSettings$pt readerSettings = Translations$readerSettings$pt.internal(_root);
	@override late final Translations$reader$pt reader = Translations$reader$pt.internal(_root);
	@override late final Translations$readerBar$pt readerBar = Translations$readerBar$pt.internal(_root);
	@override late final Translations$readerSearch$pt readerSearch = Translations$readerSearch$pt.internal(_root);
}

// Path: app
class Translations$app$pt extends Translations$app$en {
	Translations$app$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class Translations$bookshelf$pt extends Translations$bookshelf$en {
	Translations$bookshelf$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estante';
	@override String get settings => 'Configurações da Estante';
	@override String get addBook => 'Adicionar Livro (EPUB, TXT, PDF)';
	@override String get emptyTitle => 'Sua estante está vazia';
	@override String get emptyDescription => 'Toque no botão + no canto superior direito ou use\no botão abaixo para adicionar arquivos EPUB, TXT ou PDF.';
	@override String get importButton => 'Importar Livros';
	@override String get error => 'Ocorreu um erro:';
	@override String get retry => 'Tentar Novamente';
	@override String get close => 'Fechar';
	@override late final Translations$bookshelf$book$pt book = Translations$bookshelf$book$pt.internal(_root);
	@override late final Translations$bookshelf$deleteDialog$pt deleteDialog = Translations$bookshelf$deleteDialog$pt.internal(_root);
	@override late final Translations$bookshelf$importFailed$pt importFailed = Translations$bookshelf$importFailed$pt.internal(_root);
}

// Path: settingsPanel
class Translations$settingsPanel$pt extends Translations$settingsPanel$en {
	Translations$settingsPanel$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurações da Estante';
	@override String get cloudSync => 'Sincronização na Nuvem';
	@override String get syncStatus => 'Status da Sincronização';
	@override String get syncNow => 'Sincronizar Agora';
	@override String get appInfo => 'Informações do Aplicativo';
	@override String get version => 'Versão';
	@override String get engine => 'Motor';
	@override String get status => 'Status';
	@override String get darkMode => 'Modo Escuro Ativado';
	@override String get done => 'Concluído';
	@override String get syncWaiting => 'Aguardando';
	@override String get syncVerifying => 'Verificando...';
	@override String get syncing => 'Sincronizando...';
	@override String get syncCompleted => 'Sincronização Concluída';
	@override String get syncError => 'Erro de Sincronização';
}

// Path: readerSettings
class Translations$readerSettings$pt extends Translations$readerSettings$en {
	Translations$readerSettings$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurações de Leitura';
	@override String get fontSize => 'Tamanho da Fonte';
	@override String get lineSpacing => 'Espaçamento';
	@override String get brightness => 'Brilho';
	@override String get font => 'Fonte';
	@override String get haptics => 'Feedback Háptico';
	@override String get texture => 'Textura do Papel';
	@override String get sound => 'Efeitos Sonoros';
	@override String get done => 'Concluído';
	@override late final Translations$readerSettings$fontOptions$pt fontOptions = Translations$readerSettings$fontOptions$pt.internal(_root);
	@override late final Translations$readerSettings$textureOptions$pt textureOptions = Translations$readerSettings$textureOptions$pt.internal(_root);
}

// Path: reader
class Translations$reader$pt extends Translations$reader$en {
	Translations$reader$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Carregando...';
	@override String get loadingBook => 'Carregando livro...';
	@override String get search => 'Pesquisar';
}

// Path: readerBar
class Translations$readerBar$pt extends Translations$readerBar$en {
	Translations$readerBar$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => 'Capítulo Anterior';
	@override String get nextChapter => 'Próximo Capítulo';
	@override String get pageNum => 'Página';
}

// Path: readerSearch
class Translations$readerSearch$pt extends Translations$readerSearch$en {
	Translations$readerSearch$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Pesquisar no livro...';
	@override String get close => 'Fechar';
	@override String get emptyPrompt => 'Digite um termo de pesquisa.';
	@override String get noResults => 'Nenhum resultado encontrado.';
}

// Path: bookshelf.book
class Translations$bookshelf$book$pt extends Translations$bookshelf$book$en {
	Translations$bookshelf$book$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get author => 'Autor:';
	@override String get read => 'Ler';
}

// Path: bookshelf.deleteDialog
class Translations$bookshelf$deleteDialog$pt extends Translations$bookshelf$deleteDialog$en {
	Translations$bookshelf$deleteDialog$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Excluir Livro';
	@override String get message => 'Excluir da sua estante?\nEsta ação não pode ser desfeita.';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Excluir';
	@override String get removeFromShelf => 'Remover da Estante';
}

// Path: bookshelf.importFailed
class Translations$bookshelf$importFailed$pt extends Translations$bookshelf$importFailed$en {
	Translations$bookshelf$importFailed$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Falha na Importação';
	@override String get body => 'Falha ao importar o livro:';
}

// Path: readerSettings.fontOptions
class Translations$readerSettings$fontOptions$pt extends Translations$readerSettings$fontOptions$en {
	Translations$readerSettings$fontOptions$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'Gótica';
	@override String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class Translations$readerSettings$textureOptions$pt extends Translations$readerSettings$textureOptions$en {
	Translations$readerSettings$textureOptions$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'Suave';
	@override String get standard => 'Padrão';
	@override String get textured => 'Texturizada';
	@override String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <pt>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsPt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Estante',
			'bookshelf.settings' => 'Configurações da Estante',
			'bookshelf.addBook' => 'Adicionar Livro (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Sua estante está vazia',
			'bookshelf.emptyDescription' => 'Toque no botão + no canto superior direito ou use\no botão abaixo para adicionar arquivos EPUB, TXT ou PDF.',
			'bookshelf.importButton' => 'Importar Livros',
			'bookshelf.error' => 'Ocorreu um erro:',
			'bookshelf.retry' => 'Tentar Novamente',
			'bookshelf.close' => 'Fechar',
			'bookshelf.book.author' => 'Autor:',
			'bookshelf.book.read' => 'Ler',
			'bookshelf.deleteDialog.title' => 'Excluir Livro',
			'bookshelf.deleteDialog.message' => 'Excluir da sua estante?\nEsta ação não pode ser desfeita.',
			'bookshelf.deleteDialog.cancel' => 'Cancelar',
			'bookshelf.deleteDialog.delete' => 'Excluir',
			'bookshelf.deleteDialog.removeFromShelf' => 'Remover da Estante',
			'bookshelf.importFailed.title' => 'Falha na Importação',
			'bookshelf.importFailed.body' => 'Falha ao importar o livro:',
			'settingsPanel.title' => 'Configurações da Estante',
			'settingsPanel.cloudSync' => 'Sincronização na Nuvem',
			'settingsPanel.syncStatus' => 'Status da Sincronização',
			'settingsPanel.syncNow' => 'Sincronizar Agora',
			'settingsPanel.appInfo' => 'Informações do Aplicativo',
			'settingsPanel.version' => 'Versão',
			'settingsPanel.engine' => 'Motor',
			'settingsPanel.status' => 'Status',
			'settingsPanel.darkMode' => 'Modo Escuro Ativado',
			'settingsPanel.done' => 'Concluído',
			'settingsPanel.syncWaiting' => 'Aguardando',
			'settingsPanel.syncVerifying' => 'Verificando...',
			'settingsPanel.syncing' => 'Sincronizando...',
			'settingsPanel.syncCompleted' => 'Sincronização Concluída',
			'settingsPanel.syncError' => 'Erro de Sincronização',
			'readerSettings.title' => 'Configurações de Leitura',
			'readerSettings.fontSize' => 'Tamanho da Fonte',
			'readerSettings.lineSpacing' => 'Espaçamento',
			'readerSettings.brightness' => 'Brilho',
			'readerSettings.font' => 'Fonte',
			'readerSettings.haptics' => 'Feedback Háptico',
			'readerSettings.texture' => 'Textura do Papel',
			'readerSettings.sound' => 'Efeitos Sonoros',
			'readerSettings.done' => 'Concluído',
			'readerSettings.fontOptions.gothic' => 'Gótica',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Suave',
			'readerSettings.textureOptions.standard' => 'Padrão',
			'readerSettings.textureOptions.textured' => 'Texturizada',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Carregando...',
			'reader.loadingBook' => 'Carregando livro...',
			'reader.search' => 'Pesquisar',
			'readerBar.prevChapter' => 'Capítulo Anterior',
			'readerBar.nextChapter' => 'Próximo Capítulo',
			'readerBar.pageNum' => 'Página',
			'readerSearch.hint' => 'Pesquisar no livro...',
			'readerSearch.close' => 'Fechar',
			'readerSearch.emptyPrompt' => 'Digite um termo de pesquisa.',
			'readerSearch.noResults' => 'Nenhum resultado encontrado.',
			_ => null,
		};
	}
}
