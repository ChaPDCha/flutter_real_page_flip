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
class TranslationsId extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsId({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.id,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		super.$meta.setFlatMapFunction($meta.getTranslation); // copy base translations to super.$meta
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <id>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key) ?? super.$meta.getTranslation(key);

	late final TranslationsId _root = this; // ignore: unused_field

	@override 
	TranslationsId $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsId(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$id app = _Translations$app$id._(_root);
	@override late final _Translations$bookshelf$id bookshelf = _Translations$bookshelf$id._(_root);
	@override late final _Translations$settingsPanel$id settingsPanel = _Translations$settingsPanel$id._(_root);
	@override late final _Translations$readerSettings$id readerSettings = _Translations$readerSettings$id._(_root);
	@override late final _Translations$reader$id reader = _Translations$reader$id._(_root);
	@override late final _Translations$readerBar$id readerBar = _Translations$readerBar$id._(_root);
	@override late final _Translations$readerSearch$id readerSearch = _Translations$readerSearch$id._(_root);
}

// Path: app
class _Translations$app$id extends Translations$app$en {
	_Translations$app$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Realbook Reader';
}

// Path: bookshelf
class _Translations$bookshelf$id extends Translations$bookshelf$en {
	_Translations$bookshelf$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rak Buku';
	@override String get settings => 'Pengaturan Rak';
	@override String get addBook => 'Tambah Buku (EPUB, TXT, PDF)';
	@override String get emptyTitle => 'Rak buku Anda kosong';
	@override String get emptyDescription => 'Tekan tombol + di pojok kanan atas atau gunakan\ntombol di bawah untuk menambahkan file EPUB, TXT, atau PDF.';
	@override String get importButton => 'Impor Buku';
	@override String get error => 'Terjadi kesalahan:';
	@override String get retry => 'Coba Lagi';
	@override String get close => 'Tutup';
	@override late final _Translations$bookshelf$book$id book = _Translations$bookshelf$book$id._(_root);
	@override late final _Translations$bookshelf$deleteDialog$id deleteDialog = _Translations$bookshelf$deleteDialog$id._(_root);
	@override late final _Translations$bookshelf$importFailed$id importFailed = _Translations$bookshelf$importFailed$id._(_root);
}

// Path: settingsPanel
class _Translations$settingsPanel$id extends Translations$settingsPanel$en {
	_Translations$settingsPanel$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pengaturan Rak';
	@override String get cloudSync => 'Sinkronisasi Cloud';
	@override String get syncStatus => 'Status Sinkronisasi';
	@override String get syncNow => 'Sinkronisasi Sekarang';
	@override String get appInfo => 'Informasi Aplikasi';
	@override String get version => 'Versi';
	@override String get engine => 'Mesin';
	@override String get status => 'Status';
	@override String get darkMode => 'Mode Gelap Diaktifkan';
	@override String get done => 'Selesai';
	@override String get syncWaiting => 'Menunggu';
	@override String get syncVerifying => 'Memverifikasi...';
	@override String get syncing => 'Menyinkronkan...';
	@override String get syncCompleted => 'Sinkronisasi Selesai';
	@override String get syncError => 'Kesalahan Sinkronisasi';
}

// Path: readerSettings
class _Translations$readerSettings$id extends Translations$readerSettings$en {
	_Translations$readerSettings$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pengaturan Membaca';
	@override String get fontSize => 'Ukuran Huruf';
	@override String get lineSpacing => 'Spasi Baris';
	@override String get brightness => 'Kecerahan';
	@override String get font => 'Huruf';
	@override String get haptics => 'Umpan Balik Haptik';
	@override String get texture => 'Tekstur Kertas';
	@override String get sound => 'Efek Suara';
	@override String get done => 'Selesai';
	@override late final _Translations$readerSettings$fontOptions$id fontOptions = _Translations$readerSettings$fontOptions$id._(_root);
	@override late final _Translations$readerSettings$textureOptions$id textureOptions = _Translations$readerSettings$textureOptions$id._(_root);
}

// Path: reader
class _Translations$reader$id extends Translations$reader$en {
	_Translations$reader$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Memuat...';
	@override String get loadingBook => 'Memuat buku...';
	@override String get search => 'Cari';
}

// Path: readerBar
class _Translations$readerBar$id extends Translations$readerBar$en {
	_Translations$readerBar$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get prevChapter => 'Bab Sebelumnya';
	@override String get nextChapter => 'Bab Berikutnya';
	@override String get pageNum => 'Halaman';
}

// Path: readerSearch
class _Translations$readerSearch$id extends Translations$readerSearch$en {
	_Translations$readerSearch$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Cari di dalam buku...';
	@override String get close => 'Tutup';
	@override String get emptyPrompt => 'Masukkan kata kunci pencarian.';
	@override String get noResults => 'Tidak ada hasil yang ditemukan.';
}

// Path: bookshelf.book
class _Translations$bookshelf$book$id extends Translations$bookshelf$book$en {
	_Translations$bookshelf$book$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get author => 'Penulis:';
	@override String get read => 'Baca';
}

// Path: bookshelf.deleteDialog
class _Translations$bookshelf$deleteDialog$id extends Translations$bookshelf$deleteDialog$en {
	_Translations$bookshelf$deleteDialog$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hapus Buku';
	@override String get message => 'Hapus dari rak Anda?\nTindakan ini tidak dapat dibatalkan.';
	@override String get cancel => 'Batal';
	@override String get delete => 'Hapus';
	@override String get removeFromShelf => 'Hapus dari Rak';
}

// Path: bookshelf.importFailed
class _Translations$bookshelf$importFailed$id extends Translations$bookshelf$importFailed$en {
	_Translations$bookshelf$importFailed$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gagal Mengimpor';
	@override String get body => 'Gagal mengimpor buku:';
}

// Path: readerSettings.fontOptions
class _Translations$readerSettings$fontOptions$id extends Translations$readerSettings$fontOptions$en {
	_Translations$readerSettings$fontOptions$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get gothic => 'Gothic';
	@override String get myungjo => 'Myungjo';
}

// Path: readerSettings.textureOptions
class _Translations$readerSettings$textureOptions$id extends Translations$readerSettings$textureOptions$en {
	_Translations$readerSettings$textureOptions$id._(TranslationsId root) : this._root = root, super.internal(root);

	final TranslationsId _root; // ignore: unused_field

	// Translations
	@override String get smooth => 'Halus';
	@override String get standard => 'Standar';
	@override String get textured => 'Bertekstur';
	@override String get kraft => 'Kraft';
}

/// The flat map containing all translations for locale <id>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsId {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Realbook Reader',
			'bookshelf.title' => 'Rak Buku',
			'bookshelf.settings' => 'Pengaturan Rak',
			'bookshelf.addBook' => 'Tambah Buku (EPUB, TXT, PDF)',
			'bookshelf.emptyTitle' => 'Rak buku Anda kosong',
			'bookshelf.emptyDescription' => 'Tekan tombol + di pojok kanan atas atau gunakan\ntombol di bawah untuk menambahkan file EPUB, TXT, atau PDF.',
			'bookshelf.importButton' => 'Impor Buku',
			'bookshelf.error' => 'Terjadi kesalahan:',
			'bookshelf.retry' => 'Coba Lagi',
			'bookshelf.close' => 'Tutup',
			'bookshelf.book.author' => 'Penulis:',
			'bookshelf.book.read' => 'Baca',
			'bookshelf.deleteDialog.title' => 'Hapus Buku',
			'bookshelf.deleteDialog.message' => 'Hapus dari rak Anda?\nTindakan ini tidak dapat dibatalkan.',
			'bookshelf.deleteDialog.cancel' => 'Batal',
			'bookshelf.deleteDialog.delete' => 'Hapus',
			'bookshelf.deleteDialog.removeFromShelf' => 'Hapus dari Rak',
			'bookshelf.importFailed.title' => 'Gagal Mengimpor',
			'bookshelf.importFailed.body' => 'Gagal mengimpor buku:',
			'settingsPanel.title' => 'Pengaturan Rak',
			'settingsPanel.cloudSync' => 'Sinkronisasi Cloud',
			'settingsPanel.syncStatus' => 'Status Sinkronisasi',
			'settingsPanel.syncNow' => 'Sinkronisasi Sekarang',
			'settingsPanel.appInfo' => 'Informasi Aplikasi',
			'settingsPanel.version' => 'Versi',
			'settingsPanel.engine' => 'Mesin',
			'settingsPanel.status' => 'Status',
			'settingsPanel.darkMode' => 'Mode Gelap Diaktifkan',
			'settingsPanel.done' => 'Selesai',
			'settingsPanel.syncWaiting' => 'Menunggu',
			'settingsPanel.syncVerifying' => 'Memverifikasi...',
			'settingsPanel.syncing' => 'Menyinkronkan...',
			'settingsPanel.syncCompleted' => 'Sinkronisasi Selesai',
			'settingsPanel.syncError' => 'Kesalahan Sinkronisasi',
			'readerSettings.title' => 'Pengaturan Membaca',
			'readerSettings.fontSize' => 'Ukuran Huruf',
			'readerSettings.lineSpacing' => 'Spasi Baris',
			'readerSettings.brightness' => 'Kecerahan',
			'readerSettings.font' => 'Huruf',
			'readerSettings.haptics' => 'Umpan Balik Haptik',
			'readerSettings.texture' => 'Tekstur Kertas',
			'readerSettings.sound' => 'Efek Suara',
			'readerSettings.done' => 'Selesai',
			'readerSettings.fontOptions.gothic' => 'Gothic',
			'readerSettings.fontOptions.myungjo' => 'Myungjo',
			'readerSettings.textureOptions.smooth' => 'Halus',
			'readerSettings.textureOptions.standard' => 'Standar',
			'readerSettings.textureOptions.textured' => 'Bertekstur',
			'readerSettings.textureOptions.kraft' => 'Kraft',
			'reader.loading' => 'Memuat...',
			'reader.loadingBook' => 'Memuat buku...',
			'reader.search' => 'Cari',
			'readerBar.prevChapter' => 'Bab Sebelumnya',
			'readerBar.nextChapter' => 'Bab Berikutnya',
			'readerBar.pageNum' => 'Halaman',
			'readerSearch.hint' => 'Cari di dalam buku...',
			'readerSearch.close' => 'Tutup',
			'readerSearch.emptyPrompt' => 'Masukkan kata kunci pencarian.',
			'readerSearch.noResults' => 'Tidak ada hasil yang ditemukan.',
			_ => null,
		};
	}
}
