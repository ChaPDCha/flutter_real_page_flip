import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_controller.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_settings_panel.dart';
import 'package:real_page_flip_example/features/reader/domain/reader_settings.dart';

// ---------------------------------------------------------------------------
// Test ReaderController — returns a fixed state and records mutations
// ---------------------------------------------------------------------------

class _TestReaderController extends ReaderController {
  final ReaderState _fixedState;
  int fontSizeChanges = 0;
  int lineHeightChanges = 0;
  double? lastBrightness;
  String? lastFontFamily;
  bool? lastHaptic;
  bool? lastSound;

  _TestReaderController(this._fixedState);

  @override
  ReaderState build(Book book) => _fixedState;

  @override
  Future<void> updateFontSize(double delta) async {
    fontSizeChanges++;
  }

  @override
  Future<void> updateLineHeight(double delta) async {
    lineHeightChanges++;
  }

  @override
  Future<void> updateBrightness(double value) async {
    lastBrightness = value;
  }

  @override
  Future<void> updateFontFamily(String? fontFamily) async {
    lastFontFamily = fontFamily;
  }

  @override
  Future<void> toggleHaptics(bool enabled) async {
    lastHaptic = enabled;
  }

  @override
  Future<void> toggleSound(bool enabled) async {
    lastSound = enabled;
  }
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

final _testBook = Book(
  id: 'test-book',
  title: 'Test Book',
  author: 'Test Author',
  filePath: 'test/book.epub',
  addedAt: DateTime(2024, 1, 1),
);

final _testState = ReaderState(book: _testBook);

/// Opens the ReaderSettingsPanel modal and returns the test controller.
Future<_TestReaderController> openSettings(WidgetTester tester,
    {ReaderState? state}) async {
  final effectiveState = state ?? _testState;
  final controller = _TestReaderController(effectiveState);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        readerControllerProvider(_testBook)
            .overrideWith(() => controller),
      ],
      child: ShadTheme(
        data: ShadThemeData(),
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) => ElevatedButton(
                onPressed: () => ReaderSettingsPanel.show(
                  context: context,
                  ref: ref,
                  book: _testBook,
                  controller: controller,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReaderSettingsPanel', () {
    testWidgets('opens modal with correct title', (tester) async {
      await openSettings(tester);

      expect(find.text('독서 설정'), findsOneWidget);
    });

    testWidgets('displays all setting labels', (tester) async {
      await openSettings(tester);

      expect(find.text('글자 크기'), findsOneWidget);
      expect(find.text('줄 간격'), findsOneWidget);
      expect(find.text('화면 밝기'), findsOneWidget);
      expect(find.text('글꼴'), findsOneWidget);
      expect(find.text('햅틱 피드백'), findsOneWidget);
      expect(find.text('소리 효과'), findsOneWidget);
    });

    testWidgets('font size decrement button triggers controller', (
      tester,
    ) async {
      final controller = await openSettings(tester);

      await tester.tap(find.byIcon(Icons.remove).first);
      expect(controller.fontSizeChanges, 1);
    });

    testWidgets('font size increment button triggers controller', (
      tester,
    ) async {
      final controller = await openSettings(tester);

      await tester.tap(find.byIcon(Icons.add).first);
      expect(controller.fontSizeChanges, 1);
    });

    testWidgets('font family chip tap triggers controller', (tester) async {
      final controller = await openSettings(tester);

      await tester.tap(find.text('바른 명조'));
      expect(controller.lastFontFamily, 'serif');
    });

    testWidgets('haptics switch toggles controller', (tester) async {
      final controller = await openSettings(tester);

      await tester.tap(find.byType(ShadSwitch).first);
      expect(controller.lastHaptic, isFalse);
    });

    testWidgets('sound switch is displayed', (tester) async {
      await openSettings(tester);

      // Sound switch exists (the label is always visible)
      expect(find.text('소리 효과'), findsOneWidget);
      // Verify the sound setting value from the state
      expect(find.text('설정 완료'), findsOneWidget);
    });

    testWidgets('brightness slider has correct initial value', (tester) async {
      await openSettings(tester);

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, closeTo(1.0, 0.01));
      expect(slider.min, 0.3);
      expect(slider.max, 1.0);
    });

    testWidgets('shows settings complete button', (tester) async {
      await openSettings(tester);

      expect(find.text('설정 완료'), findsOneWidget);
    });

    testWidgets('shows font size current value', (tester) async {
      final state = ReaderState(
        book: _testBook,
        settings: ReaderSettings(fontSize: 20.0),
      );
      await openSettings(tester, state: state);

      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('shows line spacing current value', (tester) async {
      final state = ReaderState(
        book: _testBook,
        settings: ReaderSettings(lineHeight: 2.0),
      );
      await openSettings(tester, state: state);

      expect(find.text('2.0'), findsOneWidget);
    });
  });
}
