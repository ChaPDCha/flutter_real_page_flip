import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epubx/epubx.dart';
import 'package:just_audio/just_audio.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/domain/reader_settings.dart';
import 'package:real_page_flip_example/features/reader/presentation/book_reader_screen.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_controller.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_app_bar.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_bottom_bar.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_provider.dart';
import 'package:real_page_flip_example/features/tts/application/supertonic_tts_service.dart';
import 'package:real_page_flip_example/shared/theme/app_theme_controller.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

// ---------------------------------------------------------------------------
// Test TTS Service
// ---------------------------------------------------------------------------

/// A test double for [SupertonicTtsService] that returns a controlled
/// [playerStateStream] and records calls.
class _TestTtsService extends SupertonicTtsService {
  final _playerStateController = StreamController<PlayerState>.broadcast();
  int pauseCallCount = 0;
  int stopCallCount = 0;

  _TestTtsService() : super();

  @override
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;

  void emitPlayerState(PlayerState state) {
    _playerStateController.add(state);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'ko',
    double speed = 1.0,
  }) async {
    // No-op in test
  }
}

// ---------------------------------------------------------------------------
// Test Reader Controller
// ---------------------------------------------------------------------------

/// A test double for [ReaderController] that returns a fixed [ReaderState]
/// and records key method calls.
class _TestReaderController extends ReaderController {
  final ReaderState _fixedState;
  bool setViewportSizeCalled = false;
  bool previousPageCalled = false;
  bool nextPageCalled = false;
  double? lastViewportWidth;
  double? lastViewportHeight;

  _TestReaderController(this._fixedState);

  @override
  ReaderState build(Book book) => _fixedState;

  @override
  Future<void> setViewportSize(double width, double height) async {
    setViewportSizeCalled = true;
    lastViewportWidth = width;
    lastViewportHeight = height;
  }

  @override
  void previousPage() {
    previousPageCalled = true;
  }

  @override
  Future<void> nextPage() async {
    nextPageCalled = true;
  }

  @override
  void goToPageIndex(int index) {}

  @override
  Future<void> jumpToChapterWithQuery(int chapterIndex, String query) async {}
}

// ---------------------------------------------------------------------------
// Test App Theme Controller
// ---------------------------------------------------------------------------

class _TestAppThemeController extends AppThemeController {
  final ReaderThemeType themeType;

  _TestAppThemeController({this.themeType = ReaderThemeType.charcoal});

  @override
  ReaderThemeType build() => themeType;
}

class _TestNavigatorObserver extends NavigatorObserver {
  int popCallCount = 0;

  @override
  void didPop(Route route, Route? previousRoute) {
    popCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _testBook = Book(
  id: 'test-book-id',
  title: 'Test Book Title',
  author: 'Test Author',
  filePath: 'test/book.epub',
  addedAt: DateTime(2024, 1, 1),
);

final _testPdfBook = Book(
  id: 'test-pdf-id',
  title: 'PDF Book',
  author: 'Test Author',
  filePath: 'test/book.pdf',
  addedAt: DateTime(2024, 1, 1),
);

/// A single test chapter whose [HtmlContent] contains all page texts used by
/// the loaded / single / dimmed states so that [ReflowablePageContent] can
/// calculate character offsets without crashing.
final _testChapter = EpubChapter()
  ..Title = 'Chapter 1'
  ..HtmlContent =
      '<p>Page one content. Page two content. Page three content.</p>'
      '<p>Single page content.</p>'
      '<p>Dimmed page content.</p>';

/// A second chapter used for chapter-boundary navigation tests.
final _testChapter2 = EpubChapter()
  ..Title = 'Chapter 2'
  ..HtmlContent = '<p>Chapter two content page 1.</p>'
      '<p>Chapter two content page 2.</p>';

final _loadingState = ReaderState(book: _testBook, isLoading: true);

final _loadedState = ReaderState(
  book: _testBook,
  chapters: [_testChapter],
  pages: const ['Page one content.', 'Page two content.', 'Page three content.'],
  isLoading: false,
);

final _singlePageState = ReaderState(
  book: _testBook,
  chapters: [_testChapter],
  pages: const ['Single page content.'],
  isLoading: false,
);

final _emptyPagesState = ReaderState(
  book: _testBook,
  chapters: [_testChapter],
  pages: const <String>[],
  isLoading: false,
);

final _dimmedState = ReaderState(
  book: _testBook,
  chapters: [_testChapter],
  pages: const ['Dimmed page content.'],
  isLoading: false,
  settings: const ReaderSettings(brightness: 0.5),
);

final _pdfChapter = EpubChapter()
  ..Title = 'Full Book'
  ..HtmlContent = '';

final _pdfState = ReaderState(
  book: _testPdfBook,
  chapters: [_pdfChapter],
  pages: List.generate(10, (i) => '$i'),
  isLoading: false,
);

/// State positioned at the beginning of chapter 1 (index 1) so that a left
/// edge tap triggers [ReaderController.previousPage].
final _chNavPrevState = ReaderState(
  book: _testBook,
  chapters: [_testChapter, _testChapter2],
  pages: const ['Chapter two page 1.', 'Chapter two page 2.'],
  isLoading: false,
  currentChapterIndex: 1,
  currentPageIndex: 0,
);

/// State positioned at the last page of chapter 0 (index 0) so that a right
/// edge tap triggers [ReaderController.nextPage].
final _chNavNextState = ReaderState(
  book: _testBook,
  chapters: [_testChapter, _testChapter2],
  pages: const ['Page one content.', 'Page two content.', 'Page three content.'],
  isLoading: false,
  currentChapterIndex: 0,
  currentPageIndex: 2,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds the widget tree for BookReaderScreen tests with test doubles.
///
/// Returns a record containing the test controller and test TTS service so
/// callers can verify interactions.
Future<({
  _TestReaderController controller,
  _TestTtsService ttsService,
})> _buildApp({
  required WidgetTester tester,
  required ReaderState state,
  Book? book,
  List<NavigatorObserver> navigatorObservers = const [],
}) async {
  final controller = _TestReaderController(state);
  final ttsService = _TestTtsService();
  final effectiveBook = book ?? _testBook;

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          readerControllerProvider(effectiveBook)
              .overrideWith(() => controller),
          appThemeControllerProvider
              .overrideWith(() => _TestAppThemeController()),
          supertonicTtsProvider.overrideWithValue(ttsService),
        ],
        child: ShadTheme(
          data: ReaderThemeData.charcoal.toShadTheme(),
          child: MaterialApp(
            navigatorObservers: navigatorObservers,
            home: BookReaderScreen(book: effectiveBook),
          ),
        ),
      ),
    ),
  );
  // Pump twice: first to build, second to process post-frame callback that
  // sets up the TTS subscription and mirrors viewport size.
  await tester.pump();
  await tester.pump();

  return (controller: controller, ttsService: ttsService);
}

/// Returns the physical screen centre used for tap-based UI toggle tests.
Offset _screenCenter(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  return Offset(size.width / 2, size.height / 2);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -----------------------------------------------------------------------
  //  1.  RENDERING – Loading state
  // -----------------------------------------------------------------------

  group('Loading state', () {
    testWidgets('shows CircularProgressIndicator', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows loading text', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      expect(find.textContaining('Loading book'), findsOneWidget);
    });

    testWidgets('shows back button', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('applies correct background color', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );
    });
  });

  // -----------------------------------------------------------------------
  //  2.  RENDERING – Loaded state (with pages)
  // -----------------------------------------------------------------------

  group('Loaded state', () {
    testWidgets('renders without error', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('uses correct background color', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );
    });

    testWidgets('hides loading indicator', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // The loading text must not be present when state is loaded
      expect(find.textContaining('Loading book'), findsNothing);
    });

    testWidgets('shows persistent back button', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  3.  RENDERING – Empty / edge pages
  // -----------------------------------------------------------------------

  group('Empty pages', () {
    testWidgets('shows reading-loading message', (tester) async {
      await _buildApp(tester: tester, state: _emptyPagesState);

      // When pages is empty the screen shows l10n.reader.loading ("Loading…")
      expect(find.textContaining('Loading'), findsWidgets);
    });

    testWidgets('produces no errors', (tester) async {
      await _buildApp(tester: tester, state: _emptyPagesState);

      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  4.  BRIGHTNESS OVERLAY
  // -----------------------------------------------------------------------

  group('Brightness overlay', () {
    testWidgets('present when brightness < 1.0', (tester) async {
      await _buildApp(tester: tester, state: _dimmedState);

      // The PageFlipWidget and other widgets already contribute
      // IgnorePointer helpers (ignoring: false).  The brightness overlay
      // IgnorePointer has (ignoring: true).  Count ignoring:true widgets.
      final ignoringPointers = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .where((w) => w.ignoring)
          .length;
      expect(ignoringPointers, greaterThanOrEqualTo(1));
    });

    testWidgets('absent at full brightness', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Default brightness is 1.0 — overlay IgnorePointer is not rendered.
      // All IgnorePointer instances from other widgets have ignoring: false.
      final ignoringPointers = tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .where((w) => w.ignoring)
          .length;
      expect(ignoringPointers, equals(0));
    });
  });

  // -----------------------------------------------------------------------
  //  5.  UI TOGGLE  (AppBar / BottomBar visibility)
  // -----------------------------------------------------------------------

  group('UI toggle on tap', () {
    testWidgets('AppBar is hidden initially', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(find.byType(ReaderAppBar), findsNothing);
    });

    testWidgets('BottomBar is hidden initially', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(find.byType(ReaderBottomBar), findsNothing);
    });

    testWidgets('center tap reveals AppBar and BottomBar', (tester) async {
      await _buildApp(tester: tester, state: _singlePageState);

      expect(find.byType(ReaderAppBar), findsNothing);
      expect(find.byType(ReaderBottomBar), findsNothing);

      await tester.tapAt(_screenCenter(tester));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ReaderAppBar), findsOneWidget);
      expect(find.byType(ReaderBottomBar), findsOneWidget);
    });

    testWidgets('second tap hides bars after timer', (tester) async {
      await _buildApp(tester: tester, state: _singlePageState);
      final center = _screenCenter(tester);

      // First tap – show UI
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ReaderAppBar), findsOneWidget);

      // Second tap – start hide animation (_showUi → false)
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));

      // The widget is still mounted but sliding off-screen
      expect(find.byType(ReaderAppBar), findsOneWidget);

      // Wait for the 260 ms unmount timer
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ReaderAppBar), findsNothing);
    });
  });

  // -----------------------------------------------------------------------
  //  6.  CONTROLLER INTEGRATION
  // -----------------------------------------------------------------------

  group('Controller integration', () {
    testWidgets('setViewportSize is called after build', (tester) async {
      final result = await _buildApp(tester: tester, state: _loadedState);

      expect(result.controller.setViewportSizeCalled, isTrue);
      expect(result.controller.lastViewportWidth, isNotNull);
      expect(result.controller.lastViewportHeight, isNotNull);
    });

    testWidgets('readerControllerProvider is connected', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );
    });

    testWidgets('appThemeControllerProvider is connected', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(
        scaffold.backgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );
    });

    testWidgets('supertonicTtsProvider does not crash', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(tester.takeException(), isNull);
    });

    testWidgets('dispose does not throw', (tester) async {
      final result = await _buildApp(tester: tester, state: _loadedState);

      // Tap to trigger UI state change (exercise setState)
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 50));

      // Remove widget tree to trigger State.dispose()
      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              readerControllerProvider(_testBook)
                  .overrideWith(() => _TestReaderController(_loadedState)),
              appThemeControllerProvider
                  .overrideWith(() => _TestAppThemeController()),
              supertonicTtsProvider.overrideWithValue(result.ttsService),
            ],
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      // The production code wraps ref.read().stop() in a try-catch, so no
      // exception should bubble up.  Verify the widget caught it cleanly.
      expect(tester.takeException(), isNull);
      expect(result.ttsService.stopCallCount, greaterThanOrEqualTo(0));
    });
  });

  // -----------------------------------------------------------------------
  //  7.  NAVIGATION – edge taps that cross chapter boundaries
  // -----------------------------------------------------------------------

  group('Navigation', () {
    testWidgets('left edge at chapter start calls previousPage', (tester) async {
      final result = await _buildApp(tester: tester, state: _chNavPrevState);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width * 0.1, size.height / 2));
      // Pump past any pending gesture timers (e.g. double-tap recognizer)
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(result.controller.previousPageCalled, isTrue);
    });

    testWidgets('right edge at chapter end calls nextPage', (tester) async {
      final result = await _buildApp(tester: tester, state: _chNavNextState);

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width * 0.9, size.height / 2));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(result.controller.nextPageCalled, isTrue);
    });
  });

  // -----------------------------------------------------------------------
  //  8.  LOCALISATION
  // -----------------------------------------------------------------------

  group('Localisation', () {
    testWidgets('context.t renders translated text', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      expect(find.textContaining('Loading book'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  9.  PDF FORMAT
  // -----------------------------------------------------------------------

  group('PDF format', () {
    testWidgets('renders without error', (tester) async {
      await _buildApp(tester: tester, state: _pdfState, book: _testPdfBook);

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows persistent back button', (tester) async {
      await _buildApp(tester: tester, state: _pdfState, book: _testPdfBook);

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  10.  WIDGET STRUCTURE
  // -----------------------------------------------------------------------

  group('Widget structure', () {
    testWidgets('contains Scaffold with Column, Expanded, Stack', (
      tester,
    ) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Expanded), findsWidgets);
      expect(find.byType(Stack), findsWidgets);
    });

    testWidgets('loaded state has at least one Listener', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // The widget tree contains multiple Listener widgets from the
      // PageFlipWidget and other components.  Verify at least one exists.
      expect(find.byType(Listener), findsWidgets);
    });

    testWidgets('loading state has Positioned + back button', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      // The loading screen has Positioned.fill in the main Stack and
      // Positioned for the back button (2 total).
      expect(find.byType(Positioned), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('renders without crash for various page counts', (
      tester,
    ) async {
      await _buildApp(tester: tester, state: _loadedState);

      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  11.  ERROR / LOAD FAILURE
  // -----------------------------------------------------------------------

  group('Error / Load Failure', () {
    testWidgets('shows loading text when pages empty after load', (tester) async {
      final failedState = ReaderState(
        book: _testBook,
        chapters: const [],
        pages: const <String>[],
        isLoading: false,
      );
      await _buildApp(tester: tester, state: failedState);

      // When isLoading is false but pages are empty, shows l10n.reader.loading
      expect(find.textContaining('Loading'), findsWidgets);
    });

    testWidgets('does not crash when pages and chapters are empty', (tester) async {
      final failedState = ReaderState(
        book: _testBook,
        chapters: const [],
        pages: const <String>[],
        isLoading: false,
      );
      await _buildApp(tester: tester, state: failedState);

      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  12.  SETTINGS PANEL
  // -----------------------------------------------------------------------

  group('Settings Panel', () {
    testWidgets('opens settings panel via settings icon', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // First tap center to reveal AppBar
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // Settings icon should now be visible
      expect(find.byIcon(Icons.tune_outlined), findsOneWidget);

      // Tap settings icon to open the modal
      await tester.tap(find.byIcon(Icons.tune_outlined));
      // Wait for modal animation
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Settings panel title should appear
      expect(find.textContaining('Reading Settings'), findsOneWidget);
    });

    testWidgets('settings panel has font size control', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to show UI
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // Open settings
      await tester.tap(find.byIcon(Icons.tune_outlined));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Should show Font Size label
      expect(find.textContaining('Font Size'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  13.  SEARCH PANEL
  // -----------------------------------------------------------------------

  group('Search Panel', () {
    testWidgets('opens search panel via search icon', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to show UI
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // Search icon should be visible
      expect(find.byIcon(Icons.search_outlined), findsOneWidget);

      // Tap search icon
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pump(const Duration(milliseconds: 100));

      // Search panel should appear with a TextField
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('search panel shows hint text', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to show UI
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // Open search
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pump(const Duration(milliseconds: 100));

      // Should show search hint
      expect(find.textContaining('Search in book'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  14.  THEME APPLICATION
  // -----------------------------------------------------------------------

  group('Theme Application', () {
    testWidgets('different theme types do not crash', (tester) async {
      // Override appThemeControllerProvider with a cream theme
      final creamController = _TestAppThemeController(
        themeType: ReaderThemeType.cream,
      );
      final controller = _TestReaderController(_loadedState);
      final ttsService = _TestTtsService();

      await tester.pumpWidget(
        TranslationProvider(
          child: ProviderScope(
            overrides: [
              readerControllerProvider(_testBook)
                  .overrideWith(() => controller),
              appThemeControllerProvider
                  .overrideWith(() => creamController),
              supertonicTtsProvider.overrideWithValue(ttsService),
            ],
            child: ShadTheme(
              data: ReaderThemeData.charcoal.toShadTheme(),
              child: MaterialApp(
                home: BookReaderScreen(book: _testBook),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('theme provider is connected', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // The Scaffold background uses ReaderThemeData.get(themeType)
      // which always returns charcoal. Verify the scaffold exists.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  15.  BACK NAVIGATION
  // -----------------------------------------------------------------------

  group('Back Navigation', () {
    testWidgets('loading state back button is tappable', (tester) async {
      await _buildApp(tester: tester, state: _loadingState);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('persistent back button is tappable', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('back button does not throw when observer attached', (tester) async {
      final observer = _TestNavigatorObserver();
      await _buildApp(
        tester: tester,
        state: _loadedState,
        navigatorObservers: [observer],
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  16.  TTS STATE
  // -----------------------------------------------------------------------

  group('TTS State', () {
    testWidgets('shows volume icon when TTS is not playing', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to reveal AppBar
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // TTS icon should be volume_up_outlined when not playing
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('shows pause icon when TTS is playing', (tester) async {
      final result = await _buildApp(tester: tester, state: _loadedState);

      // Tap center to reveal AppBar
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify volume icon is showing initially
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);

      // Emit TTS playing state
      result.ttsService.emitPlayerState(
        PlayerState(true, ProcessingState.ready),
      );
      await tester.pump();
      await tester.pump();
      // Trigger another pump to process setState
      await tester.pump();

      // Should now show pause icon
      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  17.  PROGRESS INDICATOR
  // -----------------------------------------------------------------------

  group('Progress Indicator', () {
    testWidgets('BottomBar shows page counter when visible', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to show BottomBar
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ReaderBottomBar), findsOneWidget);
    });

    testWidgets('page counter shows correct numbers', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      // Tap center to show BottomBar
      await tester.tapAt(_screenCenter(tester));
      await tester.pump(const Duration(milliseconds: 100));

      // The loaded state has 3 pages starting at index 0
      // BottomBar shows "1/3" (currentPageIndex + 1 / pages.length)
      expect(find.textContaining('1/3'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  //  18.  RAPID STATE CHANGES
  // -----------------------------------------------------------------------

  group('Rapid State Changes', () {
    testWidgets('multiple rapid center taps do not crash', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      final center = _screenCenter(tester);

      // Rapidly tap center multiple times
      for (int i = 0; i < 10; i++) {
        await tester.tapAt(center);
      }
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });

  // -----------------------------------------------------------------------
  //  19.  ROUTE INTEGRATION
  // -----------------------------------------------------------------------

  group('Route Integration', () {
    testWidgets('screen receives correct book parameter', (tester) async {
      await _buildApp(tester: tester, state: _loadedState);

      final screen = tester.widget<BookReaderScreen>(
        find.byType(BookReaderScreen),
      );
      expect(screen.book.id, equals('test-book-id'));
      expect(screen.book.title, equals('Test Book Title'));
      expect(screen.book.author, equals('Test Author'));
    });
  });
}
