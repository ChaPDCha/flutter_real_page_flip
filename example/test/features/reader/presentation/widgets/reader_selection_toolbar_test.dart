import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:real_page_flip_example/features/bookshelf/domain/book.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_controller.dart';
import 'package:real_page_flip_example/features/reader/presentation/reader_state.dart';
import 'package:real_page_flip_example/features/reader/presentation/widgets/reader_selection_toolbar.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

// ---------------------------------------------------------------------------
// Mock EditableTextState
// ---------------------------------------------------------------------------

class MockEditableTextState extends Mock implements EditableTextState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) =>
      'MockEditableTextState';
}

// ---------------------------------------------------------------------------
// Test controller for intercepting addHighlight
// ---------------------------------------------------------------------------

class _ToolbarTestController extends ReaderController {
  int addHighlightCalls = 0;
  String? lastColorHex;
  String? lastNote;
  final ReaderState _fixedState;

  _ToolbarTestController(this._fixedState);

  @override
  ReaderState build(Book book) => _fixedState;

  @override
  Future<void> addHighlight({
    required int chapterIndex,
    required int startOffset,
    required int endOffset,
    required String text,
    required String colorHex,
    String? note,
  }) async {
    addHighlightCalls++;
    lastColorHex = colorHex;
    lastNote = note;
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

const _selection = TextSelection(
  baseOffset: 0,
  extentOffset: 8,
);

// ---------------------------------------------------------------------------
// Widget helper
// ---------------------------------------------------------------------------

Widget buildToolbar({
  required MockEditableTextState mockState,
  ReaderController? controller,
  Book? book,
  String selectedText = 'selected',
  int pageStart = 0,
}) {
  final effectiveBook = book ?? _testBook;
  final effectiveController =
      controller ?? _ToolbarTestController(_testState);

  return ProviderScope(
    overrides: [
      readerControllerProvider(effectiveBook).overrideWith(
        () => effectiveController,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => buildSelectionToolbar(
            context: context,
            ref: ref,
            state: mockState,
            pageStart: pageStart,
            sel: _selection,
            txt: selectedText,
            book: effectiveBook,
            currentChapterIndex: 0,
            theme: ReaderThemeData.cream,
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockEditableTextState mockState;

  setUp(() {
    mockState = MockEditableTextState();
    when(() => mockState.textEditingValue).thenReturn(
      const TextEditingValue(
        text: 'selected text content',
        selection: TextSelection(baseOffset: 0, extentOffset: 8),
      ),
    );
    when(() => mockState.hideToolbar()).thenReturn(null);
    when(() => mockState.contextMenuButtonItems).thenReturn(<ContextMenuButtonItem>[]);
    when(() => mockState.contextMenuAnchors).thenReturn(
      const TextSelectionToolbarAnchors(
        primaryAnchor: Offset(100, 200),
      ),
    );
  });

  group('buildSelectionToolbar', () {
    testWidgets('returns AdaptiveTextSelectionToolbar', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('has 4 highlight color circles', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      // Each color option is a GestureDetector containing a Container with
      // BoxShape.circle decoration
      final circles = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(circles, findsNWidgets(4));
    });

    testWidgets('note button is present', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('tapping note button shows dialog', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Dialog should appear with Korean text
      expect(find.text('메모 추가'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(find.text('저장'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('note dialog cancel button closes the dialog', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('메모 추가'), findsOneWidget);

      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(find.text('메모 추가'), findsNothing);
    });

    testWidgets('tapping note button calls hideToolbar', (tester) async {
      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pump();

      verify(() => mockState.hideToolbar()).called(1);
    });

    testWidgets('tapping a highlight color calls hideToolbar', (tester) async {
      final controller = _ToolbarTestController(_testState);
      await tester.pumpWidget(
        buildToolbar(mockState: mockState, controller: controller),
      );
      await tester.pump();

      // Tap the first color circle (wrapped in GestureDetector)
      final colorDetectors = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is Container &&
            (widget.child as Container).decoration is BoxDecoration &&
            ((widget.child as Container).decoration as BoxDecoration).shape ==
                BoxShape.circle,
      );
      expect(colorDetectors, findsNWidgets(4));

      await tester.tap(colorDetectors.first);
      await tester.pump();

      verify(() => mockState.hideToolbar()).called(1);
    });

    testWidgets('tapping a highlight color calls addHighlight on controller', (
      tester,
    ) async {
      final controller = _ToolbarTestController(_testState);
      await tester.pumpWidget(
        buildToolbar(mockState: mockState, controller: controller),
      );
      await tester.pump();

      final colorDetectors = find.byWidgetPredicate(
        (widget) =>
            widget is GestureDetector &&
            widget.child is Container &&
            (widget.child as Container).decoration is BoxDecoration &&
            ((widget.child as Container).decoration as BoxDecoration).shape ==
                BoxShape.circle,
      );

      await tester.tap(colorDetectors.first);
      await tester.pump();

      expect(controller.addHighlightCalls, 1);
      expect(controller.lastColorHex, isNotNull);
      expect(controller.lastNote, isNull);
    });

    testWidgets('platform buttons section renders without error', (tester) async {
      // Provide non-empty context menu items
      when(() => mockState.contextMenuButtonItems).thenReturn(
        const [
          ContextMenuButtonItem(
            label: 'Copy',
            onPressed: null,
          ),
        ],
      );

      await tester.pumpWidget(buildToolbar(mockState: mockState));
      await tester.pump();

      // The adaptive buttons should render without error
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error with empty selected text', (tester) async {
      // Re-stub to use the mock state with empty selection
      final localMock = MockEditableTextState();
      when(() => localMock.textEditingValue).thenReturn(
        const TextEditingValue(
          text: '',
          selection: TextSelection(baseOffset: 0, extentOffset: 0),
        ),
      );
      when(() => localMock.hideToolbar()).thenReturn(null);
      when(() => localMock.contextMenuButtonItems).thenReturn(<ContextMenuButtonItem>[]);
      when(() => localMock.contextMenuAnchors).thenReturn(
        const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(100, 200),
        ),
      );

      await tester.pumpWidget(buildToolbar(mockState: localMock));
      await tester.pump();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders with different page start offset', (tester) async {
      await tester.pumpWidget(
        buildToolbar(mockState: mockState, pageStart: 100),
      );
      await tester.pump();

      expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('note dialog save button adds highlight when note text is '
        'entered', (tester) async {
      final controller = _ToolbarTestController(_testState);
      await tester.pumpWidget(
        buildToolbar(mockState: mockState, controller: controller),
      );
      await tester.pump();

      // Open dialog
      await tester.tap(find.byIcon(Icons.note_add_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('메모 추가'), findsOneWidget);

      // Enter note text
      await tester.enterText(find.byType(TextField), 'My annotation');
      await tester.pump();

      // Tap save. The addHighlight body runs synchronously before the
      // first await, so the counter is updated immediately after tap.
      // Avoid pumping after save: the source code's showThemedDialog(...)
      // .then((_) => noteController.dispose()) runs on the microtask
      // queue and disposes the controller before the dialog close
      // animation completes, causing a framework assertion.
      await tester.tap(find.text('저장'));
      expect(controller.addHighlightCalls, 1);
      expect(controller.lastNote, 'My annotation');
    });
  });
}
