import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip/real_page_flip.dart';
import '../utils/test_helpers.dart';

void main() {
  group('PageFlipSpreadMode', () {
    test('fromIsDoubleSpread maps legacy bool', () {
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(isDoubleSpread: true),
        PageFlipSpreadMode.doubleSpread,
      );
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(isDoubleSpread: false),
        PageFlipSpreadMode.single,
      );
    });

    test('isDoubleSpread getter matches mode', () {
      expect(PageFlipSpreadMode.single.isDoubleSpread, isFalse);
      expect(PageFlipSpreadMode.doubleSpread.isDoubleSpread, isTrue);
    });

    test('PageFlipSpreadMode.values contains both enums', () {
      expect(PageFlipSpreadMode.values, hasLength(2));
      expect(
        PageFlipSpreadMode.values,
        containsAll([PageFlipSpreadMode.single, PageFlipSpreadMode.doubleSpread]),
      );
    });

    test('PageFlipSpreadMode.single.name equals single', () {
      expect(PageFlipSpreadMode.single.name, 'single');
    });

    test('PageFlipSpreadMode.doubleSpread.name equals doubleSpread', () {
      expect(PageFlipSpreadMode.doubleSpread.name, 'doubleSpread');
    });
  });

  group('PageFlipWidget with spreadMode', () {
    testWidgets('spreadMode: single does not assert', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            spreadMode: PageFlipSpreadMode.single,
            itemCount: 3,
            itemBuilder: (context, index) => Text('Page $index'),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );
      expect(find.text('Page 0'), findsOneWidget);
    });

    testWidgets('spreadMode: doubleSpread does not assert', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            spreadMode: PageFlipSpreadMode.doubleSpread,
            itemCount: 3,
            itemBuilder: (context, index) => Text('Spread $index'),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );
      expect(find.text('Spread 0'), findsOneWidget);
    });

    testWidgets('isDoubleSpread: true maps to doubleSpread mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PageFlipWidget(
            isDoubleSpread: true,
            itemCount: 3,
            itemBuilder: (context, index) => Text('Spread $index'),
            config: const PageFlipConfig(effectHandler: NoOpEffectHandler()),
          ),
        ),
      );
      expect(find.text('Spread 0'), findsOneWidget);
    });
  });
}
