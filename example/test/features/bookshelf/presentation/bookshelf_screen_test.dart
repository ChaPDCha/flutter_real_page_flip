import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book_repository.dart';
import 'package:real_page_flip_example/features/bookshelf/data/book_repository_provider.dart';
import 'package:real_page_flip_example/features/bookshelf/presentation/bookshelf_screen.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/application/sync_controller.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockBookRepository extends Mock implements BookRepository {}

// ---------------------------------------------------------------------------
// Test Navigator Observer
// ---------------------------------------------------------------------------

class _TestNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  void reset() {
    pushedRoutes.clear();
    poppedRoutes.clear();
  }
}

// ---------------------------------------------------------------------------
// Test Sync Controller -- avoids real SharedPreferences / Supabase
// ---------------------------------------------------------------------------

class _TestSyncController extends SyncController {
  final SyncState _state;
  int syncCallCount = 0;

  _TestSyncController(this._state);

  @override
  SyncState build() => _state;

  @override
  Future<void> sync() async {
    syncCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Book _createBook({
  required String id,
  required String title,
  required String author,
  String? coverImagePath,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    filePath: '/path/$id.epub',
    coverImagePath: coverImagePath,
    addedAt: DateTime.now(),
  );
}

List<Book> _createBooks({int count = 3}) {
  return List.generate(
    count,
    (i) => _createBook(id: 'book_$i', title: 'Book $i', author: 'Author $i'),
  );
}

/// Builds the bookshelf screen inside the required provider / theme / nav tree.
///
/// [provideSharedPrefs] -- when true, sets up a mocked SharedPreferences via
/// `setMockInitialValues` and overrides [sharedPreferencesProvider]. Required
/// when the widget under test triggers a provider that reads
/// `sharedPreferencesProvider` (e.g. navigation to [BookReaderScreen]).
Future<Widget> _buildApp(
  MockBookRepository repository, {
  bool provideSharedPrefs = false,
  Map<String, Object> sharedPrefsValues = const {},
  SyncController? syncController,
  List<NavigatorObserver> navigatorObservers = const [],
}) async {
  final overrides = <Override>[
    bookRepositoryProvider.overrideWithValue(repository),
  ];

  if (provideSharedPrefs) {
    SharedPreferences.setMockInitialValues(sharedPrefsValues);
    final prefs = await SharedPreferences.getInstance();
    overrides.add(sharedPreferencesProvider.overrideWithValue(prefs));
  }

  if (syncController != null) {
    overrides.add(syncControllerProvider.overrideWith(() => syncController));
  }

  return TranslationProvider(
    child: ProviderScope(
      overrides: overrides,
      child: ShadTheme(
        data: ShadThemeData(brightness: Brightness.dark),
        child: MaterialApp(
          home: const BookshelfScreen(),
          navigatorObservers: navigatorObservers,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockBookRepository mockRepository;

  setUp(() async {
    mockRepository = MockBookRepository();
  });

  // ---------------------------------------------------------------------------
  // Rendering -- Loading
  // ---------------------------------------------------------------------------

  group('Loading state', () {
    testWidgets('renders loading state with scaffold and scroll view', (
      tester,
    ) async {
      final completer = Completer<List<Book>>();
      when(() => mockRepository.getBooks()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // In the loading state the CustomScrollView and its slivers exist.
      // The skeleton grid children may not be built if outside the viewport,
      // so we verify the structural widgets.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Release so teardown is clean
      completer.complete([]);
      await tester.pump();
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering -- Empty state
  // ---------------------------------------------------------------------------

  group('Empty state', () {
    testWidgets('shows empty title and description', (tester) async {
      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.text('Bookshelf'), findsOneWidget);
      expect(find.text('Your shelf is empty'), findsOneWidget);
      expect(find.textContaining('Tap the + button'), findsOneWidget);
    });

    testWidgets('shows import button in empty state', (tester) async {
      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.text('Import Books'), findsOneWidget);
      expect(find.byIcon(Icons.file_open_outlined), findsOneWidget);
    });

    testWidgets('empty state shows book icon', (tester) async {
      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering -- Books grid
  // ---------------------------------------------------------------------------

  group('Books grid', () {
    testWidgets('renders books in a grid layout', (tester) async {
      final books = _createBooks(count: 6);
      when(() => mockRepository.getBooks()).thenAnswer((_) async => books);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.byType(SliverGrid), findsOneWidget);
    });

    testWidgets('displays book title and author on each card', (tester) async {
      final books = _createBooks(count: 3);
      when(() => mockRepository.getBooks()).thenAnswer((_) async => books);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // Each title and author appears twice in the card:
      // once inside the default cover and once below it.
      for (int i = 0; i < 3; i++) {
        expect(find.text('Book $i'), findsNWidgets(2));
        expect(find.text('Author $i'), findsNWidgets(2));
      }
    });

    testWidgets('shows default cover when coverImagePath is null', (
      tester,
    ) async {
      final book = _createBook(
        id: '1',
        title: 'Test Title',
        author: 'Test Author',
        coverImagePath: null,
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // No Image widget should exist when there is no cover image
      expect(find.byType(Image), findsNothing);
      // The default cover renders a small menu_book icon
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('renders Image.file when coverImagePath is provided', (
      tester,
    ) async {
      final book = _createBook(
        id: '1',
        title: 'Book Cover',
        author: 'Author',
        coverImagePath: '/some/cover.png',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // Image.file widget should be present (the actual file may not exist,
      // but the widget tree includes it).
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('truncates long title with ellipsis', (tester) async {
      final longTitle = 'A' * 200;
      final book = _createBook(id: '1', title: longTitle, author: 'Author');
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // The title appears twice (once in the default cover and once below).
      // Check the first instance for ellipsis properties -- both are built
      // with the same maxLines/overflow from the card (the cover uses
      // maxLines: 4, the card text uses maxLines: 1).
      final titleWidget = tester.widget<Text>(find.text(longTitle).first);
      expect(titleWidget.overflow, equals(TextOverflow.ellipsis));
    });
  });

  // ---------------------------------------------------------------------------
  // Rendering -- Error state
  // ---------------------------------------------------------------------------

  group('Error state', () {
    testWidgets('shows error icon and message when loading fails', (
      tester,
    ) async {
      when(
        () => mockRepository.getBooks(),
      ).thenAnswer((_) async => throw Exception('Network error'));

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.textContaining('Network error'), findsOneWidget);
    });

    testWidgets('shows retry button in error state', (tester) async {
      when(
        () => mockRepository.getBooks(),
      ).thenAnswer((_) async => throw Exception('fail'));

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('tapping retry refreshes the provider', (tester) async {
      when(
        () => mockRepository.getBooks(),
      ).thenAnswer((_) async => throw Exception('fail'));

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      await tester.tap(find.text('Retry'));
      await tester.pump();

      // getBooks should have been called twice (initial build + refresh)
      verify(() => mockRepository.getBooks()).called(2);
    });
  });

  // ---------------------------------------------------------------------------
  // Header / Toolbar
  // ---------------------------------------------------------------------------

  group('Header', () {
    testWidgets('displays bookshelf title', (tester) async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.text('Bookshelf'), findsOneWidget);
    });

    testWidgets('shows settings gear icon button', (tester) async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows add book icon button', (tester) async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('add book icon button is present', (tester) async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // The add icon button should be visible in the header
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('tapping a book navigates to BookReaderScreen', (tester) async {
      final observer = _TestNavigatorObserver();
      final book = _createBook(
        id: '1',
        title: 'Nav Book',
        author: 'Nav Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      // Provide sharedPreferences so BookReaderScreen can initialize.
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: MaterialApp(
                home: const BookshelfScreen(),
                navigatorObservers: [observer],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The book title appears twice (in the default cover + below the
      // cover).  Tap the second occurrence (the text below the cover).
      await tester.tap(find.text('Nav Book').last);
      await tester.pump();
      await tester.pump();

      // Verify a route was pushed (2 total: initial home + navigation)
      expect(observer.pushedRoutes.length, 2);
      final route = observer.pushedRoutes.last;
      expect(route, isA<MaterialPageRoute>());

      // Navigate back to clean up (if the reader screen is showing)
      // The reader screen has a persistent back button
      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Long-press actions modal
  // ---------------------------------------------------------------------------

  group('Book actions modal', () {
    testWidgets('long-press opens book actions sheet', (tester) async {
      final book = _createBook(
        id: '1',
        title: 'Long Press Book',
        author: 'LP Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      // Title appears twice; long-press the second occurrence
      // (the text below the cover).
      await tester.longPress(find.text('Long Press Book').last);
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('actions sheet has Read and Remove from Shelf buttons', (
      tester,
    ) async {
      final book = _createBook(
        id: '1',
        title: 'Action Book',
        author: 'Action Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Action Book').last);
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOneWidget);
      expect(find.text('Remove from Shelf'), findsOneWidget);
    });

    testWidgets('actions sheet has Close button', (tester) async {
      final book = _createBook(id: '1', title: 'Close Book', author: 'Author');
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Close Book').last);
      await tester.pumpAndSettle();

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('actions sheet shows author info', (tester) async {
      final book = _createBook(
        id: '1',
        title: 'Author Book',
        author: 'Test Author Name',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Author Book').last);
      await tester.pumpAndSettle();

      // The modal shows "Author: Test Author Name" as a single text
      expect(find.text('Author: Test Author Name'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Settings Panel
  // ---------------------------------------------------------------------------

  group('Settings panel', () {
    testWidgets('tapping settings gear opens settings modal', (tester) async {
      final syncController = _TestSyncController(
        const SyncState(status: SyncStatus.idle),
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});

      await tester.pumpWidget(
        await _buildApp(mockRepository, syncController: syncController),
      );
      await tester.pump();

      // Tap the settings gear icon
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Shelf Settings'), findsOneWidget);
    });

    testWidgets('settings modal shows sync status and app info', (
      tester,
    ) async {
      final syncController = _TestSyncController(
        const SyncState(status: SyncStatus.success),
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});

      await tester.pumpWidget(
        await _buildApp(mockRepository, syncController: syncController),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Cloud Sync'), findsOneWidget);
      expect(find.text('Sync Status'), findsOneWidget);
      expect(find.text('Sync Complete'), findsOneWidget);
      expect(find.text('Application Info'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Theme / Appearance
  // ---------------------------------------------------------------------------

  group('Theme', () {
    testWidgets('screen has correct dark background color', (tester) async {
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(
        scaffold.backgroundColor,
        equals(ReaderThemeData.charcoal.backgroundColor),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Delete book flow
  // ---------------------------------------------------------------------------

  group('Delete book flow', () {
    testWidgets('tapping Remove from Shelf shows confirmation dialog', (
      tester,
    ) async {
      final book = _createBook(
        id: '1',
        title: 'Delete Dialog',
        author: 'Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);
      when(() => mockRepository.removeBook(any())).thenAnswer((_) async {});

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Delete Dialog').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from Shelf'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Book'), findsOneWidget);
      expect(find.textContaining('Remove from your shelf'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('tapping Delete dismisses confirmation dialog', (tester) async {
      final book = _createBook(
        id: 'del1',
        title: 'Confirm Delete',
        author: 'Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Confirm Delete').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from Shelf'));
      await tester.pumpAndSettle();

      // Verify dialog is shown before tapping Delete
      expect(find.text('Delete Book'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be dismissed after tapping Delete
      expect(find.text('Delete Book'), findsNothing);
      // Actions sheet should also be dismissed
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('tapping Cancel dismisses dialog without removing', (
      tester,
    ) async {
      final book = _createBook(
        id: '2',
        title: 'Cancel Delete',
        author: 'Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);
      when(() => mockRepository.removeBook(any())).thenAnswer((_) async {});

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(home: BookshelfScreen()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Cancel Delete').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove from Shelf'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockRepository.removeBook(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // Read button in actions sheet
  // ---------------------------------------------------------------------------

  group('Read button in actions sheet', () {
    testWidgets('tapping Read navigates to BookReaderScreen', (tester) async {
      final observer = _TestNavigatorObserver();
      final book = _createBook(
        id: '1',
        title: 'Read Action Nav',
        author: 'Author',
      );
      when(() => mockRepository.getBooks()).thenAnswer((_) async => [book]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: MaterialApp(
                home: const BookshelfScreen(),
                navigatorObservers: [observer],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.longPress(find.text('Read Action Nav').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read'));
      await tester.pump();
      await tester.pump();

      // should have pushed a route beyond the initial home
      expect(observer.pushedRoutes.length, greaterThanOrEqualTo(2));

      // Navigate back to clean up
      final backButton = find.byIcon(Icons.arrow_back_ios_new);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pump();
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Loading skeleton
  // ---------------------------------------------------------------------------

  group('Loading skeleton', () {
    testWidgets('renders loading grid structure without book content', (
      tester,
    ) async {
      final completer = Completer<List<Book>>();
      when(() => mockRepository.getBooks()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(await _buildApp(mockRepository));
      // Multiple pumps to allow sliver child builder to populate
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // The loading state renders a SliverGrid for skeleton items
      expect(find.byType(SliverGrid), findsOneWidget);
      // No book titles appear during loading
      expect(find.text('Book 0'), findsNothing);

      completer.complete([]);
      await tester.pump();
    });
  });

  // ---------------------------------------------------------------------------
  // i18n
  // ---------------------------------------------------------------------------

  group('i18n', () {
    testWidgets('renders English locale correctly via explicit locale', (
      tester,
    ) async {
      // Explicitly set English locale to verify TranslationProvider wiring.
      LocaleSettings.setLocaleSync(AppLocale.en);

      SharedPreferences.setMockInitialValues({'demo_book_created': true});
      when(() => mockRepository.getBooks()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              bookRepositoryProvider.overrideWithValue(mockRepository),
            ],
            child: ShadTheme(
              data: ShadThemeData(brightness: Brightness.dark),
              child: const MaterialApp(
                locale: Locale('en'),
                home: BookshelfScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // English text should render correctly
      expect(find.text('Bookshelf'), findsOneWidget);
      expect(find.text('Your shelf is empty'), findsOneWidget);
      expect(find.text('Import Books'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation guard
  // ---------------------------------------------------------------------------

  group('Navigation guard', () {
    testWidgets('no book content tappable during loading state', (
      tester,
    ) async {
      final completer = Completer<List<Book>>();
      when(() => mockRepository.getBooks()).thenAnswer((_) => completer.future);

      await tester.pumpWidget(await _buildApp(mockRepository));
      await tester.pump();

      // Basic structure is present during loading
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CustomScrollView), findsOneWidget);

      // No book titles or author names appear during loading
      expect(find.text('Book 0'), findsNothing);
      expect(find.text('Author 0'), findsNothing);

      completer.complete([]);
      await tester.pump();
    });
  });
}
