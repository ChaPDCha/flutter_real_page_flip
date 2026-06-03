import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archive/archive.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book_repository.dart';
import 'package:real_page_flip_example/features/bookshelf/data/book_repository_provider.dart';
import 'package:real_page_flip_example/features/bookshelf/presentation/bookshelf_controller.dart';

class MockBookRepository extends Mock implements BookRepository {}

// Programmatic minimal EPUB builder for tests
List<int> createMinimalEpubBytes({String title = 'Test Title', String author = 'Test Author'}) {
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
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>''';
  final opfData = contentOpf.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/content.opf', opfData.length, opfData));
  
  // 3.5 OEBPS/toc.ncx
  const tocXml = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="db_id"/>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
  </head>
  <docTitle><text>Test Title</text></docTitle>
  <navMap>
    <navPoint id="navpoint-1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.html"/>
    </navPoint>
  </navMap>
</ncx>''';
  final tocData = tocXml.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/toc.ncx', tocData.length, tocData));
  
  // 4. OEBPS/chapter1.html
  const chapterXml = '''<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>Chapter 1</title></head>
<body><p>Hello Test World</p></body>
</html>''';
  final chapterData = chapterXml.codeUnits;
  archive.addFile(ArchiveFile('OEBPS/chapter1.html', chapterData.length, chapterData));

  final encoder = ZipEncoder();
  return encoder.encode(archive)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfController Tests', () {
    late MockBookRepository mockRepository;
    late Directory tempDocDir;
    late File dummyEpubFile;

    setUpAll(() {
      registerFallbackValue(Book(
        id: 'fallback',
        title: 'fallback',
        author: 'fallback',
        filePath: 'fallback',
        addedAt: DateTime(2026),
      ));
    });

    setUp(() async {
      mockRepository = MockBookRepository();
      tempDocDir = await Directory.systemTemp.createTemp();
      
      // Mock getApplicationDocumentsDirectory method channel
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDocDir.path;
        }
        return null;
      });

      // Write minimal EPUB to temporary file
      dummyEpubFile = File('${tempDocDir.path}/temp_book.epub');
      await dummyEpubFile.writeAsBytes(createMinimalEpubBytes());
    });

    tearDown(() async {
      try {
        if (await tempDocDir.exists()) {
          await tempDocDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          bookRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );
      container.listen(bookshelfControllerProvider, (_, __) {});
      addTearDown(container.dispose);
      return container;
    }

    test('Initial build loads books from repository', () async {
      final now = DateTime.now();
      final mockBooks = [
        Book(id: '1', title: 'Book 1', author: 'Author 1', filePath: 'path/1', addedAt: now),
      ];
      when(() => mockRepository.getBooks()).thenAnswer((_) async => mockBooks);

      final container = createContainer();
      
      // Initially state should load
      final state = await container.read(bookshelfControllerProvider.future);
      expect(state, equals(mockBooks));
      verify(() => mockRepository.getBooks()).called(1);
    });

    test('importEpub successfully copies file, parses metadata and saves to repo', () async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);
      when(() => mockRepository.addBook(any())).thenAnswer((_) async {});

      final container = createContainer();
      // Await build to avoid race condition
      await container.read(bookshelfControllerProvider.future);
      final controller = container.read(bookshelfControllerProvider.notifier);

      // Perform import
      await controller.importEpub(dummyEpubFile);

      // Verify repository added the book
      verify(() => mockRepository.addBook(any())).called(1);

      // Verify the file was copied to target doc directory
      final copiedBooksDir = Directory('${tempDocDir.path}/books');
      expect(await copiedBooksDir.exists(), isTrue);
      final files = await copiedBooksDir.list().toList();
      expect(files.length, equals(1));
      expect(files.first.path.endsWith('.epub'), isTrue);
    });

    test('importEpub handles parsing errors gracefully and sets AsyncError state', () async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);
      
      final corruptFile = File('${tempDocDir.path}/corrupt.epub');
      await corruptFile.writeAsBytes([1, 2, 3, 4, 5]); // Invalid zip bytes

      final container = createContainer();
      // Await build to avoid race condition
      await container.read(bookshelfControllerProvider.future);
      final controller = container.read(bookshelfControllerProvider.notifier);

      await controller.importEpub(corruptFile);

      // State should have error
      final state = container.read(bookshelfControllerProvider);
      expect(state.hasError, isTrue);
    });

    test('removeBook deletes files from disk and removes from repository', () async {
      const bookId = 'book_to_delete';
      final filePath = '${tempDocDir.path}/books/$bookId.epub';
      final coverPath = '${tempDocDir.path}/covers/$bookId.png';

      // Create dummy book files on disk
      await File(filePath).create(recursive: true);
      await File(coverPath).create(recursive: true);

      final book = Book(
        id: bookId,
        title: 'Book',
        author: 'Author',
        filePath: filePath,
        coverImagePath: coverPath,
        addedAt: DateTime.now(),
      );

      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);
      when(() => mockRepository.removeBook(bookId)).thenAnswer((_) async {});

      final container = createContainer();
      // Await build to avoid race condition
      await container.read(bookshelfControllerProvider.future);
      final controller = container.read(bookshelfControllerProvider.notifier);

      // Perform removal
      await controller.removeBook(bookId);

      // Verify files deleted
      expect(await File(filePath).exists(), isFalse);
      expect(await File(coverPath).exists(), isFalse);

      // Verify repository removeBook was called
      verify(() => mockRepository.removeBook(bookId)).called(1);
    });
  });
}
