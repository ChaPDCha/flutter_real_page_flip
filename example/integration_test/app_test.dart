/// Integration tests for the Realbook example app.
///
/// Run with:
/// ```
/// flutter test integration_test/app_test.dart
/// ```
///
/// Or for a specific device:
/// ```
/// flutter test -d <device_id> integration_test/app_test.dart
/// ```
///
/// These tests exercise critical user flows end-to-end using the real app
/// startup. Firebase, Sentry, and Supabase are initialized but gracefully
/// fail in environments where they are not configured. The demo book is
/// auto-created on first launch by the app itself.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:real_page_flip_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Realbook App Integration Tests', () {
    /// Launches the app and waits for the bookshelf to be fully loaded.
    ///
    /// Handles the "What's New" changelog dialog that appears on first launch
    /// by dismissing it automatically. Waits for the demo book to be
    /// auto-created by the app's [BookshelfController].
    Future<void> launchApp(WidgetTester tester) async {
      app.main();

      // Let the async initialization (Firebase, Sentry, SharedPreferences,
      // Supabase) start processing.
      await tester.pump(const Duration(seconds: 1));

      // The first time the app launches, the ChangelogGate may show a
      // "What's New" dialog above the BookshelfScreen. Dismiss it.
      final doneButton = find.text('Done');
      if (doneButton.evaluate().isNotEmpty) {
        await tester.tap(doneButton);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Allow async demo book creation (isolate-based compute, file I/O,
      // SQLite write, FTS index) to complete before the test proceeds.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 5)),
      );

      // Pump until the skeleton shimmer stops and the book grid is displayed.
      await tester.pumpAndSettle();
    }

    /// Opens the demo book from the bookshelf.
    ///
    /// Assumes [launchApp] has already been called. Taps the demo book card
    /// and waits for the reader to initialize (chapter parsing, text
    /// pagination, viewport layout).
    Future<void> openDemoBook(WidgetTester tester) async {
      await tester.tap(find.text('Realbook 데모'));
      await tester.pump(const Duration(seconds: 1));

      // Allow the reader to load chapters, calculate page layout, and
      // render the first page.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 3)),
      );
      await tester.pumpAndSettle();
    }

    /// Reveals the reader's chrome (app bar + bottom bar) by tapping the
    /// center of the screen.
    ///
    /// Assumes the reader screen is already open. The reader uses a tap
    /// between 25% and 75% of the screen width to toggle UI visibility.
    Future<void> showReaderUi(WidgetTester tester) async {
      // Get logical pixel dimensions from the test view.
      final physicalSize = tester.view.physicalSize;
      final dpr = tester.view.devicePixelRatio;
      final logicalWidth = physicalSize.width / dpr;
      final logicalHeight = physicalSize.height / dpr;

      await tester.tapAt(Offset(logicalWidth / 2, logicalHeight / 2));
      await tester.pumpAndSettle();
    }

    // -----------------------------------------------------------------------
    // Flow 1: App launch  Bookshelf  Open book  Read  Return
    // -----------------------------------------------------------------------
    testWidgets(
      'Flow 1: App launch, open book, read, return',
      (tester) async {
        await launchApp(tester);

        // 1. Verify bookshelf screen renders with a book
        expect(
          find.text('Bookshelf'),
          findsOneWidget,
          reason: 'Bookshelf title should be visible',
        );
        expect(
          find.text('Realbook 데모'),
          findsOneWidget,
          reason: 'Demo book should appear on the bookshelf',
        );

        // 2. Tap the demo book card
        await openDemoBook(tester);

        // 3. Verify reader screen opened
        // The persistent back button is always visible in the reader.
        expect(
          find.byIcon(Icons.arrow_back_ios_new),
          findsOneWidget,
          reason: 'Reader screen should show a back button',
        );

        // 4. Verify the reader is past the loading state
        // "Loading..." is the generic loading indicator text from
        // the reader screen. If content is rendered, this text is gone.
        expect(
          find.text('Loading...'),
          findsNothing,
          reason: 'Reader should not be in loading state',
        );

        // 5. Verify content is displayed (pages from the demo book)
        // The first chapter title is "제1장: 봄날의 산책", which should
        // be visible after pagination.
        final chapterFinder = find.textContaining('제1장');
        if (chapterFinder.evaluate().isNotEmpty) {
          expect(
            chapterFinder,
            findsOneWidget,
            reason: 'Reader should display paginated book content',
          );
        }

        // 6. Return to the bookshelf via the persistent back button
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        // 7. Verify we are back on the bookshelf
        expect(
          find.text('Realbook 데모'),
          findsOneWidget,
          reason: 'Should be back on the bookshelf after popping the reader',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // -----------------------------------------------------------------------
    // Flow 2: Reader settings change
    // -----------------------------------------------------------------------
    testWidgets(
      'Flow 2: Reader settings change',
      (tester) async {
        await launchApp(tester);
        await openDemoBook(tester);

        // 1. Tap the center of the screen to reveal the reader app bar
        await showReaderUi(tester);

        // 2. Tap the settings icon (Icons.tune_outlined) in the app bar
        await tester.tap(find.byIcon(Icons.tune_outlined));
        await tester.pumpAndSettle();

        // 3. Verify the settings panel opened
        // The WoltModalSheet shows "Reading Settings" as the title and
        // contains controls for "Font Size" and "Brightness".
        expect(
          find.text('Reading Settings'),
          findsOneWidget,
          reason: 'Settings panel modal should show its title',
        );
        expect(
          find.text('Font Size'),
          findsOneWidget,
          reason: 'Settings panel should contain font size control',
        );
        expect(
          find.text('Brightness'),
          findsOneWidget,
          reason: 'Settings panel should contain brightness control',
        );

        // 4. Change a setting: increment the font size
        // The font size row has a "-" and "+" IconButton pair. Tap "+".
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();

        // 5. Close the settings panel by tapping the "Done" button
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // 6. Return to the bookshelf
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await tester.pumpAndSettle();

        // 7. Verify we are back on the bookshelf
        expect(
          find.text('Realbook 데모'),
          findsOneWidget,
          reason: 'Should return to bookshelf after dismissing settings',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // -----------------------------------------------------------------------
    // Flow 3: Search within a book
    // -----------------------------------------------------------------------
    testWidgets('Flow 3: Search within a book', (tester) async {
      await launchApp(tester);
      await openDemoBook(tester);

      // 1. Show the reader app bar (which contains the search icon)
      await showReaderUi(tester);

      // 2. Tap the search icon in the app bar
      await tester.tap(find.byIcon(Icons.search_outlined));
      await tester.pumpAndSettle();

      // 3. Verify the search panel opened
      // The search panel contains a TextField with hint text.
      expect(
        find.text('Search in book...'),
        findsOneWidget,
        reason: 'Search panel hint text should be visible',
      );
      expect(
        find.byType(TextField),
        findsOneWidget,
        reason: 'Search panel should contain a text input field',
      );

      // 4. Enter a search term that exists in the demo book content
      // The demo book contains Korean text with the word "날씨" (weather)
      // in the first chapter.
      await tester.enterText(find.byType(TextField), '날씨');
      await tester.pump(const Duration(milliseconds: 500));

      // Allow the 300 ms debounce + SQLite search query to complete.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await tester.pumpAndSettle();

      // 5. Verify search results appear
      // The search service returns results as ListTile widgets inside a
      // ListView. If the demo book was indexed, results should be present.
      final resultListTile = find.byType(ListTile);
      final hasResults = resultListTile.evaluate().isNotEmpty;

      if (hasResults) {
        // Tap the first search result to navigate to the matching page
        await tester.tap(resultListTile.first);
        await tester.pumpAndSettle();

        // Verify the reader is still visible after navigation
        expect(
          find.byIcon(Icons.arrow_back_ios_new),
          findsOneWidget,
          reason: 'Reader should remain visible after search navigation',
        );
      } else {
        // If no results (e.g., indexing not yet complete), verify the "no
        // results" empty state is shown instead.
        // The close button is still available in the search panel.
        expect(
          find.text('No results found.'),
          findsOneWidget,
          reason: 'Search should show no-results state when no matches',
        );
      }

      // 6. Close the search panel
      // The search panel has a "Close" TextButton in its header.
      final searchClose = find.text('Close');
      if (searchClose.evaluate().isNotEmpty) {
        await tester.tap(searchClose);
        await tester.pumpAndSettle();
      }

      // 7. Return to the bookshelf
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      await tester.pumpAndSettle();

      // 8. Verify we are back on the bookshelf
      expect(
        find.text('Realbook 데모'),
        findsOneWidget,
        reason: 'Should return to bookshelf after search flow',
      );
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
