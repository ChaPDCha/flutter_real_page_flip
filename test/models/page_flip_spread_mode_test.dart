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

    test('values contains both modes', () {
      expect(PageFlipSpreadMode.values, hasLength(2));
      expect(
        PageFlipSpreadMode.values,
        containsAll([PageFlipSpreadMode.single, PageFlipSpreadMode.doubleSpread]),
      );
    });

    test('enum indices are in declaration order', () {
      expect(PageFlipSpreadMode.single.index, 0);
      expect(PageFlipSpreadMode.doubleSpread.index, 1);
    });

    test('enum names match declaration names', () {
      expect(PageFlipSpreadMode.single.name, 'single');
      expect(PageFlipSpreadMode.doubleSpread.name, 'doubleSpread');
    });

    test('equality: same values are equal', () {
      expect(PageFlipSpreadMode.single, PageFlipSpreadMode.single);
      expect(
        PageFlipSpreadMode.doubleSpread,
        PageFlipSpreadMode.doubleSpread,
      );
    });

    test('equality: different values are not equal', () {
      expect(
        PageFlipSpreadMode.single,
        isNot(equals(PageFlipSpreadMode.doubleSpread)),
      );
    });

    test('isDoubleSpread getter is reflexive', () {
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(isDoubleSpread: true)
            .isDoubleSpread,
        isTrue,
      );
      expect(
        PageFlipSpreadModeCompat.fromIsDoubleSpread(isDoubleSpread: false)
            .isDoubleSpread,
        isFalse,
      );
    });

    test('hashCode distinguishes modes', () {
      expect(
        PageFlipSpreadMode.single.hashCode,
        isNot(equals(PageFlipSpreadMode.doubleSpread.hashCode)),
      );
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
