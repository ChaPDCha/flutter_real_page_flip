import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import 'utils/test_helpers.dart';

void main() {
  group('PageFlipWidget double-spread mode', () {
    testWidgets('forward drag flips to next page', (tester) async {
      int currentIndex = 0;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 0,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      // Drag from right side, half-width forward
      final gesture = await tester.startGesture(const Offset(350, 300));
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      // The state controller uses flat index, so flip advances by 1.
      // The consumer maps flat indices to spreads externally.
      expect(currentIndex, equals(1));
    });

    testWidgets('backward drag flips to previous page', (tester) async {
      int currentIndex = 0;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            initialIndex: 2,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(currentIndex, equals(1));
    });

    testWidgets('insufficient drag snaps back without page change',
        (tester) async {
      int currentIndex = 0;
      int changedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 0,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) {
              currentIndex = index;
              changedCount++;
            },
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(350, 300));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedCount, equals(0));
      expect(currentIndex, equals(0));
    });

    testWidgets('programmatic nextPage works in double-spread',
        (tester) async {
      int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 0,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(currentIndex, equals(1), reason: 'nextPage advances by 1');
    });

    testWidgets('programmatic previousPage works in double-spread',
        (tester) async {
      int currentIndex = 2;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 2,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.previousPage();
      await tester.pumpAndSettle();

      expect(currentIndex, equals(1), reason: 'previousPage goes back by 1');
    });

    testWidgets('goToPage works in double-spread mode',
        (tester) async {
      int currentIndex = 0;
      final controller = PageFlipController();

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            controller: controller,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) => currentIndex = index,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      await controller.goToPage(4);
      await tester.pumpAndSettle();

      expect(currentIndex, equals(4));
    });

    testWidgets('boundary prevents flipping past last page',
        (tester) async {
      int changedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 5, // last page of 6
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (_) => changedCount++,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      // Try to flip forward from last page
      final gesture = await tester.startGesture(const Offset(350, 300));
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedCount, equals(0));
    });

    testWidgets('boundary prevents flipping before first spread',
        (tester) async {
      int changedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            initialIndex: 0,
            itemCount: 6,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (_) => changedCount++,
            isDoubleSpread: true,
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(200, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(changedCount, equals(0));
    });

    testWidgets('spreadMode enum matches isDoubleSpread behavior',
        (tester) async {
      // Verify spreadMode: PageFlipSpreadMode.doubleSpread produces
      // the same visual layout as isDoubleSpread: true
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 4,
            spreadMode: PageFlipSpreadMode.doubleSpread,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      // Widget renders without error
      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('single spread mode default renders without error',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 4,
            spreadMode: PageFlipSpreadMode.single,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('double-spread with odd page count renders without crash',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            isDoubleSpread: true,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      expect(find.byType(PageFlipWidget), findsOneWidget);
    });

    testWidgets('onPageChanged fires once per double-spread drag flip',
        (tester) async {
      int callCount = 0;
      int lastIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 6,
            isDoubleSpread: true,
            itemBuilder: (context, index) =>
                Container(key: Key('page_$index')),
            onPageChanged: (index) {
              callCount++;
              lastIndex = index;
            },
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(350, 300));
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(lastIndex, equals(1));
    });
  });
}
