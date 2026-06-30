import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/page_flip.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'utils/test_helpers.dart';

void main() {
  group('PageFlipWidget callbacks', () {
    testWidgets('onPageChanged fires exactly once per successful transition',
        (tester) async {
      var callCount = 0;
      int? lastIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) {
              callCount++;
              lastIndex = index;
            },
          ),
        ),
      );

      // Use controller to flip
      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(lastIndex, equals(1));
    });

    testWidgets('onPageFlipped fires exactly once per successful transition',
        (tester) async {
      var callCount = 0;
      int? lastIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageFlipped: (index) {
              callCount++;
              lastIndex = index;
            },
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(callCount, equals(1));
      expect(lastIndex, equals(1));
    });

    testWidgets('both callbacks receive identical index values',
        (tester) async {
      int? changedIndex;
      int? flippedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (index) => changedIndex = index,
            onPageFlipped: (index) => flippedIndex = index,
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(changedIndex, equals(flippedIndex));
      expect(changedIndex, equals(1));
    });

    testWidgets('neither callback fires on out-of-bounds goToPage',
        (tester) async {
      var changedCount = 0;
      var flippedCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (_) => changedCount++,
            onPageFlipped: (_) => flippedCount++,
            onFlipStart: () {},
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );

      // goToPage with negative index
      await state.goToPage(-1);
      await tester.pumpAndSettle();
      expect(changedCount, equals(0));
      expect(flippedCount, equals(0));

      // goToPage with index >= itemCount
      await state.goToPage(100);
      await tester.pumpAndSettle();
      expect(changedCount, equals(0));
      expect(flippedCount, equals(0));
    });

    testWidgets(
        'onFlipStart and onFlipEnd fire during a successful programmatic flip',
        (tester) async {
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onFlipStart: () => startCount++,
            onFlipEnd: () => endCount++,
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(startCount, equals(1));
      expect(endCount, equals(1));
    });

    testWidgets(
        'animated programmatic flip fires lifecycle callbacks exactly once',
        (tester) async {
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onFlipStart: () => startCount++,
            onFlipEnd: () => endCount++,
            config: const PageFlipConfig(
              skipTapAnimation: false,
              effectHandler: NoOpEffectHandler(),
            ),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(startCount, equals(1));
      expect(endCount, equals(1));
    });

    testWidgets(
        'onFlipStart and onFlipEnd fire during a programmatically cancelled flip (snapback)',
        (tester) async {
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onFlipStart: () => startCount++,
            onFlipEnd: () => endCount++,
          ),
        ),
      );

      // Drag a small distance (within cutoff) and release (which triggers onDragEnd with isSuccess = false)
      final gesture = await tester.startGesture(const Offset(300, 300));
      await gesture.moveBy(const Offset(-30, 0)); // small drag to the left
      await gesture.up();
      await tester.pumpAndSettle();

      expect(startCount, equals(1));
      expect(endCount, equals(1));
    });

    testWidgets(
        'onFlipEnd fires during a boundary swipe at the first page (gesture reject)',
        (tester) async {
      var startCount = 0;
      var endCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onFlipStart: () => startCount++,
            onFlipEnd: () => endCount++,
          ),
        ),
      );

      // Start a drag gesture in the "backward" direction at the first page (swipe right)
      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(150, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(startCount, equals(1));
      expect(endCount, equals(1));
    });

    testWidgets('onHandleEffect custom handler fires with correct event',
        (tester) async {
      PageFlipEvent? capturedEvent;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onHandleEffect: (effect, {intensity, volume, texture, resistance}) {
              capturedEvent = effect;
            },
            config: const PageFlipConfig(
              skipTapAnimation: false,
              enableSound: false,
              enableHaptics: false,
            ),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(capturedEvent, isNotNull);
    });

    testWidgets('onEffectError reports custom effect handler failures',
        (tester) async {
      final reportedEffects = <PageFlipEvent>[];
      final reportedErrors = <Object>[];

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onHandleEffect: (effect, {intensity, volume, texture, resistance}) {
              throw StateError('effect failed');
            },
            onEffectError: (effect, error, stackTrace) {
              reportedEffects.add(effect);
              reportedErrors.add(error);
            },
            config: const PageFlipConfig(skipTapAnimation: false),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(reportedEffects, isNotEmpty);
      expect(reportedErrors.whereType<StateError>(), isNotEmpty);
    });

    testWidgets('onPageChanged does not fire on insufficient drag (snap-back)',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (_) => callCount++,
            config: const PageFlipConfig(
              cutoffForward: 0.5,
              effectHandler: NoOpEffectHandler(),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(const Offset(300, 300));
      await gesture.moveBy(const Offset(-50, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(callCount, equals(0));
    });

    testWidgets('onFlipStart fires before onPageChanged in programmatic flip',
        (tester) async {
      final callOrder = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onFlipStart: () => callOrder.add('start'),
            onPageChanged: (_) => callOrder.add('changed'),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(
        callOrder.indexOf('start'),
        lessThan(callOrder.indexOf('changed')),
      );
    });

    testWidgets('onFlipEnd fires after onPageChanged in programmatic flip',
        (tester) async {
      final callOrder = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            onPageChanged: (_) => callOrder.add('changed'),
            onFlipEnd: () => callOrder.add('end'),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();

      expect(callOrder.last, equals('end'));
    });

    testWidgets('custom effect handler override via config works',
        (tester) async {
      var handlerTriggerCount = 0;

      final customHandler = _TestEffectHandler(
        onEffect: () => handlerTriggerCount++,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            itemCount: 5,
            itemBuilder: (context, index) => Text('Page $index'),
            config: PageFlipConfig(
              effectHandler: customHandler,
            ),
          ),
        ),
      );

      final state = tester.state<PageFlipWidgetState>(
        find.byType(PageFlipWidget),
      );
      state.nextPage();
      await tester.pumpAndSettle();
    });
  });
}

class _TestEffectHandler implements PageFlipEffectHandler {
  _TestEffectHandler({required this.onEffect});

  final VoidCallback onEffect;

  @override
  void onHandleEffect(
    PageFlipEvent event, {
    int? pageIndex,
    int? intensity,
    double? volume,
    double? texture,
    double? resistance,
  }) {
    onEffect();
  }

  @override
  set viewportWidth(double width) {}

  @override
  void dispose() {}
}
