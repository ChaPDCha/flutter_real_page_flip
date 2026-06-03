import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_controller.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';

List<int> createMultiChapterEpubBytes({
  String title = 'Test Title',
  String author = 'Test Author',
  String chapter1Content = 'This is chapter one content. It should contain enough text to test.',
  String chapter2Content = 'This is chapter two content. The journey continues here.',
}) {
  final archive = Archive();
  
  // 1. mimetype file
  final mimetypeData = 'application/epub+zip'.codeUnits;
  archive.addFile(ArchiveFile('mimetype', mimetypeData.length, mimetypeData)..compress = false);
  
  // 2. META-INF/container.xml
  const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  final containerData = containerXml.codeUnits;
  archive.addFile(ArchiveFile('META-INF/container.xml', containerData.length, containerData));
  
  // 3. OEBPS/content.opf
  final contentOpf = '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="db_id" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="chapter1" href="chapter1.html" media-type="application/xhtml+xml"/>
    <item id="chapter2" href="chapter2.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
    <itemref idref="chapter2"/>
  </spine>
</package>''';
  final opfData = contentOpf.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/content.opf', opfData.length, opfData));
  
  // 3.5 OEBPS/toc.ncx
  final tocXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="db_id"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>$title</text></docTitle>
  <navMap>
    <navPoint id="navpoint-1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.html"/>
    </navPoint>
    <navPoint id="navpoint-2" playOrder="2">
      <navLabel><text>Chapter 2</text></navLabel>
      <content src="chapter2.html"/>
    </navPoint>
  </navMap>
</ncx>''';
  final tocData = tocXml.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/toc.ncx', tocData.length, tocData));
  
  // 4. OEBPS/chapter1.html
  final chapter1Xml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body><p>$chapter1Content</p></body>
</html>''';
  final chapter1Data = chapter1Xml.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/chapter1.html', chapter1Data.length, chapter1Data));

  // 5. OEBPS/chapter2.html
  final chapter2Xml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 2</title></head>
<body><p>$chapter2Content</p></body>
</html>''';
  final chapter2Data = chapter2Xml.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/chapter2.html', chapter2Data.length, chapter2Data));

  final encoder = ZipEncoder();
  return encoder.encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderController Tests', () {
    late Directory tempDir;
    late File epubFile;
    late Book testBook;

    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      tempDir = await Directory.systemTemp.createTemp();
      // Mock path_provider Method Channel
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      });

      epubFile = File('${tempDir.path}/test_reader_book.epub');
      await epubFile.writeAsBytes(createMultiChapterEpubBytes());
      
      testBook = Book(
        id: 'test_reader_book_id',
        title: 'Test Title',
        author: 'Test Author',
        filePath: epubFile.path,
        addedAt: DateTime.now(),
      );
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      // Keep provider active in Riverpod
      container.listen(readerControllerProvider(testBook), (_, __) {});
      addTearDown(container.dispose);
      return container;
    }

    Future<void> waitForInitialization(ProviderContainer container) async {
      final provider = readerControllerProvider(testBook);
      while (container.read(provider).isLoading) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
    }

    test('ReaderController initializes and loads EPUB chapters and settings', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final state = container.read(readerControllerProvider(testBook));
      expect(state.isLoading, isFalse);
      expect(state.epubBook, isNotNull);
      expect(state.chapters.length, equals(2));
      expect(state.currentChapterIndex, equals(0));
      expect(state.currentPageIndex, equals(0));
    });

    test('setViewportSize triggers paging calculations', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      
      // Initially, no pages are calculated because viewport size is 0
      var state = container.read(readerControllerProvider(testBook));
      expect(state.pages, isEmpty);

      // Set standard viewport size
      controller.setViewportSize(375.0, 667.0);
      state = container.read(readerControllerProvider(testBook));

      expect(state.viewportWidth, equals(375.0));
      expect(state.viewportHeight, equals(667.0));
      expect(state.pages, isNotEmpty);
      expect(state.pages.first, contains('This is chapter one content'));
    });

    test('Navigation: next page and previous page inside single chapter', () async {
      // Create EPUB with long text that splits into multiple pages
      final longChapter1 = 'Paragraph 1. ' * 50;
      await epubFile.writeAsBytes(createMultiChapterEpubBytes(chapter1Content: longChapter1));

      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      controller.setViewportSize(375.0, 300.0); // Small height to ensure multiple pages

      var state = container.read(readerControllerProvider(testBook));
      expect(state.pages.length, greaterThan(1));
      expect(state.currentPageIndex, equals(0));

      // Go to next page
      controller.nextPage();
      state = container.read(readerControllerProvider(testBook));
      expect(state.currentPageIndex, equals(1));

      // Go to previous page
      controller.previousPage();
      state = container.read(readerControllerProvider(testBook));
      expect(state.currentPageIndex, equals(0));
    });

    test('Navigation: next page crosses chapter boundary', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      controller.setViewportSize(375.0, 667.0);

      var state = container.read(readerControllerProvider(testBook));
      expect(state.currentChapterIndex, equals(0));
      expect(state.currentPageIndex, equals(0));
      expect(state.pages.length, equals(1)); // Short content fits in 1 page

      // Next page should move to chapter 1 (index 1), page 0
      controller.nextPage();
      state = container.read(readerControllerProvider(testBook));

      expect(state.currentChapterIndex, equals(1));
      expect(state.currentPageIndex, equals(0));
      expect(state.pages.first, contains('This is chapter two content'));

      // If we call nextPage again at the end of last chapter, it should do nothing
      controller.nextPage();
      state = container.read(readerControllerProvider(testBook));
      expect(state.currentChapterIndex, equals(1));
      expect(state.currentPageIndex, equals(0));
    });

    test('Navigation: previous page crosses chapter boundary', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      controller.setViewportSize(375.0, 667.0);

      // Start at chapter 1, page 0
      controller.nextPage();
      var state = container.read(readerControllerProvider(testBook));
      expect(state.currentChapterIndex, equals(1));

      // Previous page should move back to chapter 0, page index (last page of chapter 0)
      controller.previousPage();
      state = container.read(readerControllerProvider(testBook));

      expect(state.currentChapterIndex, equals(0));
      expect(state.currentPageIndex, equals(0));
      expect(state.pages.first, contains('This is chapter one content'));

      // Calling previousPage at chapter 0 page 0 should do nothing
      controller.previousPage();
      state = container.read(readerControllerProvider(testBook));
      expect(state.currentChapterIndex, equals(0));
      expect(state.currentPageIndex, equals(0));
    });

    test('Settings: Font size and toggles save to SharedPreferences', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      controller.setViewportSize(375.0, 667.0);

      var state = container.read(readerControllerProvider(testBook));
      final originalFontSize = state.settings.fontSize;

      // Increase font size
      await controller.updateFontSize(2.0);
      state = container.read(readerControllerProvider(testBook));
      expect(state.settings.fontSize, equals(originalFontSize + 2.0));

      // Toggle haptics & sound
      await controller.toggleHaptics(false);
      await controller.toggleSound(true);
      state = container.read(readerControllerProvider(testBook));
      expect(state.settings.enableHaptics, isFalse);
      expect(state.settings.enableSound, isTrue);

      // Verify values persist in SharedPreferences
      final jsonStr = prefs.getString('reader_settings');
      expect(jsonStr, isNotNull);

      final Map<String, dynamic> savedMap = json.decode(jsonStr!);
      expect(savedMap['fontSize'], equals(originalFontSize + 2.0));
      expect(savedMap.containsKey('themeType'), isFalse);
      expect(savedMap['enableHaptics'], isFalse);
      expect(savedMap['enableSound'], isTrue);
    });

    test('Reading progress: persists and reloads successfully', () async {
      final container = createContainer();
      await waitForInitialization(container);

      final controller = container.read(readerControllerProvider(testBook).notifier);
      controller.setViewportSize(375.0, 667.0);

      // Move to chapter 1
      controller.nextPage();
      var state = container.read(readerControllerProvider(testBook));
      expect(state.currentChapterIndex, equals(1));
      
      // Verify SharedPreferences has progress stored
      final prefs = await SharedPreferences.getInstance();
      final progressKey = 'reader_progress_${testBook.id}';
      final progressStr = prefs.getString(progressKey);
      expect(progressStr, isNotNull);

      final Map<String, dynamic> progressMap = json.decode(progressStr!);
      expect(progressMap['chapterIndex'], equals(1));
      expect(progressMap['pageIndex'], equals(0));

      // Create a brand new container (simulating app relaunch)
      final newContainer = ProviderContainer();
      newContainer.listen(readerControllerProvider(testBook), (_, __) {});
      addTearDown(newContainer.dispose);

      await Future.delayed(const Duration(milliseconds: 5));
      while (newContainer.read(readerControllerProvider(testBook)).isLoading) {
        await Future.delayed(const Duration(milliseconds: 5));
      }

      final newState = newContainer.read(readerControllerProvider(testBook));
      expect(newState.currentChapterIndex, equals(1));
      expect(newState.currentPageIndex, equals(0));
    });
  });
}
