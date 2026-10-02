import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';

/// Shared setup for the foldable and dual-surface suites.
///
/// Foldable devices change the book's shape in one step: the window jumps
/// between a cover display and an inner display (and between portrait and
/// landscape) while the reader is mid-book.
///
/// The shapes below are the proportions of the displays the engine is
/// expected to run on. Only the proportions matter to the engine, so they are
/// plain logical sizes at device pixel ratio 1:
///
/// * Galaxy Z Fold8: 7.6" inner 2448x1848 (4:3), 5.5" cover 1248x1972 (10:16).
/// * Galaxy Z Fold8 Ultra: 8.0" inner 2504x2256 (10:9), 6.5" cover 2520x1080
///   (21:9).
/// * iPhone Duo: 7.6" inner and 5.4" outer displays that share one aspect
///   ratio (Apple's announcement). Apple does not state the ratio, so the
///   shapes here assume a 4:3 inner display opened like a book and a 3:4 outer
///   display.
class FoldShape {
  const FoldShape(this.name, this.size);

  final String name;
  final Size size;

  double get aspect => size.width / size.height;
}

const cover10x16 = FoldShape('cover 10:16', Size(416, 657));
const inner4x3Landscape = FoldShape('inner 4:3 landscape', Size(816, 616));
const inner3x4Portrait = FoldShape('inner 3:4 portrait', Size(616, 816));
const cover21x9 = FoldShape('cover 21:9', Size(360, 840));
const inner10x9Portrait = FoldShape('inner 9:10 portrait', Size(752, 835));
const outer3x4 = FoldShape('outer 3:4', Size(390, 520));

/// Fold / unfold / rotate transitions between those shapes.
const foldTransitions = <(FoldShape, FoldShape)>[
  (cover10x16, inner4x3Landscape),
  (inner4x3Landscape, cover10x16),
  (cover10x16, inner3x4Portrait),
  (cover21x9, inner10x9Portrait),
  (inner10x9Portrait, cover21x9),
  (outer3x4, inner4x3Landscape),
];

const foldItemCount = 12;
const foldStartIndex = 4;

Widget foldBook({
  PageFlipSpreadMode mode = PageFlipSpreadMode.single,
  int itemCount = foldItemCount,
  int initialIndex = foldStartIndex,
  ValueChanged<int>? onPageChanged,
  VoidCallback? onFlipStart,
  VoidCallback? onFlipEnd,
  Duration duration = const Duration(milliseconds: 200),
}) =>
    MaterialApp(
      home: Scaffold(
        body: PageFlipWidget(
          itemCount: itemCount,
          initialIndex: initialIndex,
          spreadMode: mode,
          onPageChanged: onPageChanged,
          onFlipStart: onFlipStart,
          onFlipEnd: onFlipEnd,
          config: PageFlipConfig(
            duration: duration,
            enableHaptics: false,
            enableSound: false,
          ),
          itemBuilder: (context, index) => ColoredBox(
            color: Color(0xFF000000 | ((index * 0x151515) & 0xFFFFFF)),
            child: Center(child: Text('page $index')),
          ),
        ),
      ),
    );

PageFlipWidgetState foldStateOf(WidgetTester tester) =>
    tester.state<PageFlipWidgetState>(find.byType(PageFlipWidget));

/// The host pattern documented in the README ("Foldables, dual-screen devices
/// and window resizing"): pick single page or two-page spread from the shape
/// of the window, and carry the reader's page across the switch.
class ReadingHost extends StatefulWidget {
  const ReadingHost({required this.controller, super.key});

  final PageFlipController controller;

  @override
  State<ReadingHost> createState() => ReadingHostState();
}

class ReadingHostState extends State<ReadingHost> {
  static const pageCount = 24;

  /// The reader's page, in single-page numbering.
  int page = 0;

  /// Every index `onPageChanged` delivered, exactly as delivered.
  final List<int> reported = <int>[];
  int flipStarts = 0;
  int flipEnds = 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final spread = constraints.maxWidth >= constraints.maxHeight * 1.2;
          return PageFlipWidget(
            controller: widget.controller,
            spreadMode: spread
                ? PageFlipSpreadMode.doubleSpread
                : PageFlipSpreadMode.single,
            itemCount: spread ? (pageCount + 1) ~/ 2 : pageCount,
            initialIndex: spread ? page ~/ 2 : page,
            onFlipStart: () => flipStarts++,
            onFlipEnd: () => flipEnds++,
            onPageChanged: (index) {
              reported.add(index);
              setState(() => page = spread ? index * 2 : index);
            },
            config: const PageFlipConfig(
              duration: Duration(milliseconds: 400),
              enableHaptics: false,
              enableSound: false,
            ),
            itemBuilder: (context, index) => spread
                ? Row(
                    children: <Widget>[
                      Expanded(child: Center(child: Text('page ${index * 2}'))),
                      Expanded(
                        child: Center(child: Text('page ${index * 2 + 1}')),
                      ),
                    ],
                  )
                : Center(child: Text('page $index')),
          );
        },
      );
}

void resizeViewTo(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
}

/// Pumps the book at [size] and waits until its first captures have landed.
Future<PageFlipWidgetState> openFoldBook(
  WidgetTester tester,
  Size size, {
  PageFlipSpreadMode mode = PageFlipSpreadMode.single,
}) async {
  tester.view.devicePixelRatio = 1;
  resizeViewTo(tester, size);
  await tester.pumpWidget(foldBook(mode: mode));
  await tester.pumpAndSettle();
  return foldStateOf(tester);
}

/// Pumps [frames] frames of 16 ms each.
Future<void> pumpFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// Aspect ratio of the snapshot kept for [index], or null if it has none.
double? snapshotAspect(PageFlipWidgetState state, int index) {
  final size = state.debugSnapshotPixelSize(index);
  if (size == null) return null;
  return size.width / size.height;
}

/// Every snapshot the next turn can draw (current page and both neighbours)
/// has the viewport's proportions.
bool windowMatches(PageFlipWidgetState state, Size viewport) {
  final aspect = viewport.width / viewport.height;
  final current = state.controller.currentIndex;
  for (final index in <int>[current - 1, current, current + 1]) {
    if (index < 0 || index >= foldItemCount) continue;
    final snapshot = snapshotAspect(state, index);
    if (snapshot == null) return false;
    if ((snapshot / aspect - 1).abs() > 0.01) return false;
  }
  return true;
}

/// Largest stretch of any snapshot currently drawn by the flip layer: how far
/// each image's proportions are from the box it was squeezed into.
double worstDrawnDistortion(WidgetTester tester) {
  var worst = 1.0;
  for (final element in find.byType(RawImage).evaluate()) {
    final image = (element.widget as RawImage).image;
    final box = element.renderObject as RenderBox?;
    if (image == null || box == null || !box.hasSize) continue;
    if (box.size.isEmpty || image.height == 0) continue;
    final stretch =
        (box.size.width / box.size.height) / (image.width / image.height);
    final factor = stretch >= 1 ? stretch : 1 / stretch;
    if (factor > worst) worst = factor;
  }
  return worst;
}
