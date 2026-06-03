import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/flip_layer_policy.dart';
import 'package:real_page_flip/src/widgets/flip_middle_layer_stack.dart';

void main() {
  const canvasSize = Size(400, 300);

  group('FlipMiddleLayerStack', () {
    testWidgets('double-spread forward includes spine reveal clipper', (
      tester,
    ) async {
      final geo = PageFlipGeometry(
        progress: 0.9,
        isRightToLeft: true,
        touchOffset: const Offset(350, 150),
        size: canvasSize,
        isDoubleSpread: true,
        isForward: true,
      );
      final policy = FlipLayerPolicy(
        isDoubleSpread: true,
        isForward: true,
        currentIndex: 0,
        itemCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: FlipMiddleLayerStack(
                middleLayerContent: const ColoredBox(color: Colors.blue),
                geo: geo,
                policy: policy,
                floatProgress: 0.9,
                isDoubleSpread: true,
                isForward: true,
                touchPosition: const Offset(350, 150),
                spreadHalfBuilder: (_, __) => const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipClipper,
        ),
        findsOneWidget,
      );
    });

    testWidgets('single-page mode omits spine reveal clipper', (tester) async {
      final geo = PageFlipGeometry(
        progress: 0.5,
        isRightToLeft: true,
        touchOffset: const Offset(350, 150),
        size: canvasSize,
        isDoubleSpread: false,
        isForward: true,
      );
      final policy = FlipLayerPolicy(
        isDoubleSpread: false,
        isForward: true,
        currentIndex: 0,
        itemCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox.fromSize(
              size: canvasSize,
              child: FlipMiddleLayerStack(
                middleLayerContent: const ColoredBox(color: Colors.green),
                geo: geo,
                policy: policy,
                floatProgress: 0.5,
                isDoubleSpread: false,
                isForward: true,
                touchPosition: const Offset(350, 150),
                spreadHalfBuilder: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is PageFlipSpineRevealClipper,
        ),
        findsNothing,
      );
    });
  });
}
