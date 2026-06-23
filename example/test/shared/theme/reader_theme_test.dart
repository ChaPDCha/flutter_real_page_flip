import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

void main() {
  group('ReaderThemeData', () {
    test('toMaterialTheme uses cream palette colors', () {
      final material = ReaderThemeData.cream.toMaterialTheme();

      expect(
        material.scaffoldBackgroundColor,
        ReaderThemeData.cream.backgroundColor,
      );
      expect(material.colorScheme.primary, ReaderThemeData.cream.accentColor);
      expect(
        material.dialogTheme.backgroundColor,
        ReaderThemeData.cream.panelColor,
      );
    });

    test('toMaterialTheme uses charcoal palette colors', () {
      final material = ReaderThemeData.charcoal.toMaterialTheme();

      expect(material.brightness, Brightness.dark);
      expect(
        material.scaffoldBackgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );
      expect(
        material.colorScheme.onSurface,
        ReaderThemeData.charcoal.textColor,
      );
    });

    test('cover helpers derive from active theme', () {
      expect(
        ReaderThemeData.cream.coverBackgroundColor,
        ReaderThemeData.cream.panelColor,
      );
      expect(
        ReaderThemeData.charcoal.coverBackgroundColor,
        const Color(0xFF2A2A2A),
      );
    });
  });
}
