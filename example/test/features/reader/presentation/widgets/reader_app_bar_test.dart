import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_app_bar.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

Widget _wrapWithProviders(Widget child) {
  return TranslationProvider(child: MaterialApp(home: child));
}

void main() {
  group('ReaderAppBar', () {
    final testBook = Book(
      id: 'test-book',
      title: 'Test Book Title',
      author: 'Test Author',
      filePath: 'test/book.epub',
      addedAt: DateTime(2024, 1, 1),
    );

    Widget buildAppBar({
      bool showUi = true,
      Book? book,
      bool isTtsPlaying = false,
      VoidCallback? onBack,
      VoidCallback? onTtsPressed,
      VoidCallback? onSettingsPressed,
      VoidCallback? onSearchPressed,
    }) {
      return _wrapWithProviders(
        Scaffold(
          body: Stack(
            children: [
              ReaderAppBar(
                showUi: showUi,
                book: book ?? testBook,
                readerState: ReaderState(book: testBook, isLoading: false),
                themeData: ReaderThemeData.cream,
                isTtsPlaying: isTtsPlaying,
                onBack: onBack ?? () {},
                onTtsPressed: onTtsPressed ?? () {},
                onSettingsPressed: onSettingsPressed ?? () {},
                onSearchPressed: onSearchPressed ?? () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders and displays book title', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(find.text('Test Book Title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back button is present and calls onBack', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildAppBar(onBack: () => tapped = true));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
      expect(tapped, isTrue);
    });

    testWidgets('search button is present and calls onSearchPressed', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        buildAppBar(onSearchPressed: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.search_outlined));
      expect(tapped, isTrue);
    });

    testWidgets('TTS button shows volume_up icon when not playing', (
      tester,
    ) async {
      await tester.pumpWidget(buildAppBar(isTtsPlaying: false));
      await tester.pump();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(find.byIcon(Icons.pause_circle_outline), findsNothing);
    });

    testWidgets('TTS button shows pause icon when playing', (tester) async {
      await tester.pumpWidget(buildAppBar(isTtsPlaying: true));
      await tester.pump();

      expect(find.byIcon(Icons.pause_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
    });

    testWidgets('TTS button calls onTtsPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildAppBar(onTtsPressed: () => tapped = true));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.volume_up_outlined));
      expect(tapped, isTrue);
    });

    testWidgets('settings button is present and calls onSettingsPressed', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        buildAppBar(onSettingsPressed: () => tapped = true),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.tune_outlined));
      expect(tapped, isTrue);
    });

    testWidgets('PDF mode hides trailing buttons', (tester) async {
      final pdfBook = Book(
        id: 'test-pdf',
        title: 'PDF Book',
        author: 'Test',
        filePath: 'test/book.pdf',
        addedAt: DateTime(2024, 1, 1),
      );
      await tester.pumpWidget(buildAppBar(book: pdfBook));
      await tester.pump();

      expect(find.byIcon(Icons.search_outlined), findsNothing);
      expect(find.byIcon(Icons.volume_up_outlined), findsNothing);
      expect(find.byIcon(Icons.tune_outlined), findsNothing);
      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('showUi=false renders without error', (tester) async {
      await tester.pumpWidget(buildAppBar(showUi: false));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ReaderAppBar), findsOneWidget);
    });

    testWidgets('back button icon is arrow_back_ios_new', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    });

    testWidgets('bar uses ClipRect with BackdropFilter', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(find.byType(ClipRect), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('AnimatedPositioned and AnimatedOpacity are used', (
      tester,
    ) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(find.byType(AnimatedPositioned), findsOneWidget);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    testWidgets('NavigationToolbar is present', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(find.byType(NavigationToolbar), findsOneWidget);
    });

    testWidgets('title has maxLines 1 and overflow ellipsis', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      final titleWidget = tester.widget<Text>(find.text('Test Book Title'));
      expect(titleWidget.maxLines, 1);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('renders without error with default props', (tester) async {
      await tester.pumpWidget(buildAppBar());
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
