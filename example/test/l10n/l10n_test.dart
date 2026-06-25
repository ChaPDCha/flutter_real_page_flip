import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

void main() {
  group('AppLocale enum', () {
    test('supports all 10 locales', () {
      expect(AppLocale.values.length, 10);
      expect(AppLocale.en, isA<AppLocale>());
      expect(AppLocale.ko, isA<AppLocale>());
      expect(AppLocale.es, isA<AppLocale>());
      expect(AppLocale.fil, isA<AppLocale>());
      expect(AppLocale.fr, isA<AppLocale>());
      expect(AppLocale.id, isA<AppLocale>());
      expect(AppLocale.pt, isA<AppLocale>());
      expect(AppLocale.ptBr, isA<AppLocale>());
      expect(AppLocale.zh, isA<AppLocale>());
      expect(AppLocale.ja, isA<AppLocale>());
    });
  });

  group('All translations', () {
    for (final locale in AppLocale.values) {
      test('${locale.name} has all sections with non-empty values', () async {
        final t = await locale.build();

        // app
        expect(t.app.title, isNotEmpty);

        // bookshelf
        expect(t.bookshelf.title, isNotEmpty);
        expect(t.bookshelf.settings, isNotEmpty);
        expect(t.bookshelf.addBook, isNotEmpty);
        expect(t.bookshelf.emptyTitle, isNotEmpty);
        expect(t.bookshelf.emptyDescription, isNotEmpty);
        expect(t.bookshelf.importButton, isNotEmpty);
        expect(t.bookshelf.error, isNotEmpty);
        expect(t.bookshelf.retry, isNotEmpty);
        expect(t.bookshelf.close, isNotEmpty);
        expect(t.bookshelf.book.author, isNotEmpty);
        expect(t.bookshelf.book.read, isNotEmpty);
        expect(t.bookshelf.deleteDialog.title, isNotEmpty);
        expect(t.bookshelf.deleteDialog.message, isNotEmpty);
        expect(t.bookshelf.deleteDialog.cancel, isNotEmpty);
        expect(t.bookshelf.deleteDialog.delete, isNotEmpty);
        expect(t.bookshelf.deleteDialog.removeFromShelf, isNotEmpty);
        expect(t.bookshelf.importFailed.title, isNotEmpty);
        expect(t.bookshelf.importFailed.body, isNotEmpty);

        // settingsPanel
        expect(t.settingsPanel.title, isNotEmpty);
        expect(t.settingsPanel.cloudSync, isNotEmpty);
        expect(t.settingsPanel.syncStatus, isNotEmpty);
        expect(t.settingsPanel.syncNow, isNotEmpty);
        expect(t.settingsPanel.appInfo, isNotEmpty);
        expect(t.settingsPanel.version, isNotEmpty);
        expect(t.settingsPanel.engine, isNotEmpty);
        expect(t.settingsPanel.status, isNotEmpty);
        expect(t.settingsPanel.darkMode, isNotEmpty);
        expect(t.settingsPanel.done, isNotEmpty);
        expect(t.settingsPanel.syncWaiting, isNotEmpty);
        expect(t.settingsPanel.syncVerifying, isNotEmpty);
        expect(t.settingsPanel.syncing, isNotEmpty);
        expect(t.settingsPanel.syncCompleted, isNotEmpty);
        expect(t.settingsPanel.syncError, isNotEmpty);

        // readerSettings
        expect(t.readerSettings.title, isNotEmpty);
        expect(t.readerSettings.fontSize, isNotEmpty);
        expect(t.readerSettings.lineSpacing, isNotEmpty);
        expect(t.readerSettings.brightness, isNotEmpty);
        expect(t.readerSettings.font, isNotEmpty);
        expect(t.readerSettings.haptics, isNotEmpty);
        expect(t.readerSettings.texture, isNotEmpty);
        expect(t.readerSettings.sound, isNotEmpty);
        expect(t.readerSettings.done, isNotEmpty);
        expect(t.readerSettings.fontOptions.gothic, isNotEmpty);
        expect(t.readerSettings.fontOptions.myungjo, isNotEmpty);
        expect(t.readerSettings.textureOptions.smooth, isNotEmpty);
        expect(t.readerSettings.textureOptions.standard, isNotEmpty);
        expect(t.readerSettings.textureOptions.textured, isNotEmpty);
        expect(t.readerSettings.textureOptions.kraft, isNotEmpty);

        // reader
        expect(t.reader.loading, isNotEmpty);
        expect(t.reader.loadingBook, isNotEmpty);
        expect(t.reader.search, isNotEmpty);

        // readerBar
        expect(t.readerBar.prevChapter, isNotEmpty);
        expect(t.readerBar.nextChapter, isNotEmpty);
        expect(t.readerBar.pageNum, isNotEmpty);

        // readerSearch
        expect(t.readerSearch.hint, isNotEmpty);
        expect(t.readerSearch.close, isNotEmpty);
        expect(t.readerSearch.emptyPrompt, isNotEmpty);
        expect(t.readerSearch.noResults, isNotEmpty);
      });
    }
  });

  group('Locale switching', () {
    test('can switch between locales at runtime', () async {
      // Switch to Korean
      final ko = await AppLocale.ko.build();
      expect(ko.bookshelf.title, '서재');

      // Switch to Japanese
      final ja = await AppLocale.ja.build();
      expect(ja.bookshelf.title, '本棚');

      // Switch back to English
      final en = await AppLocale.en.build();
      expect(en.bookshelf.title, 'Bookshelf');
    });

    test('supported locales list contains all 10', () {
      final supported = AppLocaleUtils.supportedLocales;
      expect(supported.length, 10);
    });
  });
}
