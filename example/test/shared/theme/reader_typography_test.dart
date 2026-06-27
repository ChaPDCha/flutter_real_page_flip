import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/shared/theme/reader_typography.dart';

void main() {
  group('ReaderTypography', () {
    // ---------------------------------------------------------------------------
    // _isTest
    // ---------------------------------------------------------------------------

    test('_isTest returns true in test environment', () {
      // The private getter checks:
      //   !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')
      // Both conditions should be true inside a Flutter unit test.
      expect(kIsWeb, false);
      expect(Platform.environment.containsKey('FLUTTER_TEST'), true);
    });

    // ---------------------------------------------------------------------------
    // getUiStyle
    // ---------------------------------------------------------------------------

    group('getUiStyle', () {
      test('returns default TextStyle with correct font family', () {
        final style = ReaderTypography.getUiStyle();

        expect(style.fontFamily, 'sans-serif');
        expect(style.letterSpacing, -0.2);
        // Other properties should default to null when not provided
        expect(style.fontSize, isNull);
        expect(style.color, isNull);
        expect(style.fontWeight, isNull);
      });

      test('passes through fontSize', () {
        final style = ReaderTypography.getUiStyle(fontSize: 18.0);

        expect(style.fontSize, 18.0);
      });

      test('passes through color', () {
        const expectedColor = Colors.blue;
        final style = ReaderTypography.getUiStyle(color: expectedColor);

        expect(style.color, expectedColor);
      });

      test('passes through fontWeight', () {
        final style = ReaderTypography.getUiStyle(fontWeight: FontWeight.bold);

        expect(style.fontWeight, FontWeight.bold);
      });

      test('overrides letterSpacing when provided', () {
        final style = ReaderTypography.getUiStyle(letterSpacing: 1.5);

        expect(style.letterSpacing, 1.5);
      });

      test('uses default letterSpacing of -0.2 when not provided', () {
        final style = ReaderTypography.getUiStyle(fontSize: 14.0);

        expect(style.letterSpacing, -0.2);
      });
    });

    // ---------------------------------------------------------------------------
    // getGeometricStyle
    // ---------------------------------------------------------------------------

    group('getGeometricStyle', () {
      test('returns default TextStyle with correct font family', () {
        final style = ReaderTypography.getGeometricStyle();

        expect(style.fontFamily, 'sans-serif');
        expect(style.letterSpacing, 0.0);
        expect(style.fontSize, isNull);
        expect(style.color, isNull);
        expect(style.fontWeight, isNull);
      });

      test('passes through all parameters', () {
        const color = Color(0xFF123456);
        final style = ReaderTypography.getGeometricStyle(
          fontSize: 24.0,
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        );

        expect(style.fontSize, 24.0);
        expect(style.color, color);
        expect(style.fontWeight, FontWeight.w600);
        expect(style.letterSpacing, -0.5);
      });

      test('uses default letterSpacing of 0.0 when not provided', () {
        final style = ReaderTypography.getGeometricStyle(fontSize: 12.0);

        expect(style.letterSpacing, 0.0);
      });
    });

    // ---------------------------------------------------------------------------
    // getBookStyle
    // ---------------------------------------------------------------------------

    group('getBookStyle', () {
      test('returns default sans-serif style when no fontFamily', () {
        const color = Colors.black;
        final style = ReaderTypography.getBookStyle(
          fontSize: 16.0,
          color: color,
        );

        expect(style.fontFamily, 'sans-serif');
        expect(style.fontSize, 16.0);
        expect(style.color, color);
        expect(style.fontWeight, FontWeight.w400);
        expect(style.letterSpacing, -0.2);
        expect(style.height, 1.6);
      });

      test('returns serif fontFamily when requested', () {
        const color = Colors.black;
        final style = ReaderTypography.getBookStyle(
          fontSize: 18.0,
          color: color,
          fontFamily: 'serif',
        );

        expect(style.fontFamily, 'serif');
        expect(style.fontWeight, FontWeight.w400);
        expect(style.letterSpacing, -0.2);
      });

      test('returns sans-serif for non-serif fontFamily', () {
        const color = Colors.black;
        final style = ReaderTypography.getBookStyle(
          fontSize: 20.0,
          color: color,
          fontFamily: 'custom-font',
        );

        expect(style.fontFamily, 'sans-serif');
      });

      test('passes through custom lineHeight', () {
        const color = Colors.black;
        final style = ReaderTypography.getBookStyle(
          fontSize: 14.0,
          color: color,
          lineHeight: 2.0,
        );

        expect(style.height, 2.0);
      });

      test('passes through color correctly', () {
        const customColor = Color(0xFFE0E0E0);
        final style = ReaderTypography.getBookStyle(
          fontSize: 16.0,
          color: customColor,
        );

        expect(style.color, customColor);
      });
    });

    // ---------------------------------------------------------------------------
    // getChapterHeaderStyle
    // ---------------------------------------------------------------------------

    group('getChapterHeaderStyle', () {
      test('returns bold style with 1.4x base font size for sans-serif', () {
        const color = Colors.black;
        final style = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 16.0,
          color: color,
        );

        expect(style.fontFamily, 'sans-serif');
        expect(style.fontSize, closeTo(22.4, 0.01)); // 16 * 1.4
        expect(style.height, 1.4);
        expect(style.color, color);
        expect(style.fontWeight, FontWeight.bold);
        expect(style.letterSpacing, -0.5);
      });

      test('returns serif fontFamily when requested', () {
        const color = Colors.black;
        final style = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 20.0,
          color: color,
          fontFamily: 'serif',
        );

        expect(style.fontFamily, 'serif');
        expect(style.fontSize, closeTo(28.0, 0.01)); // 20 * 1.4
        expect(style.fontWeight, FontWeight.bold);
      });

      test('returns sans-serif for non-serif fontFamily', () {
        const color = Colors.black;
        final style = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 14.0,
          color: color,
          fontFamily: 'monospace',
        );

        expect(style.fontFamily, 'sans-serif');
      });

      test('uses default lineHeight of 1.4', () {
        const color = Colors.black;
        final style = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 16.0,
          color: color,
        );

        expect(style.height, 1.4);
      });

      test('produces larger font for larger baseFontSize', () {
        const color = Colors.black;
        final small = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 12.0,
          color: color,
        );
        final large = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 24.0,
          color: color,
        );

        expect(small.fontSize, lessThan(large.fontSize!));
        expect(small.fontSize, closeTo(16.8, 0.01));
        expect(large.fontSize, closeTo(33.6, 0.01));
      });

      test('applies letterSpacing of -0.5', () {
        const color = Colors.black;
        final style = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 16.0,
          color: color,
        );

        expect(style.letterSpacing, -0.5);
      });
    });

    // ---------------------------------------------------------------------------
    // Cross-method consistency
    // ---------------------------------------------------------------------------

    group('cross-method consistency', () {
      test('getBookStyle and getChapterHeaderStyle share letterSpacing sign', () {
        const color = Colors.black;
        final book = ReaderTypography.getBookStyle(fontSize: 16.0, color: color);
        final header = ReaderTypography.getChapterHeaderStyle(
          baseFontSize: 16.0,
          color: color,
        );

        // Both use negative letter spacing (for Korean typography)
        expect(book.letterSpacing!, lessThan(0));
        expect(header.letterSpacing!, lessThan(0));
      });

      test('getUiStyle and getGeometricStyle have different default spacing', () {
        final ui = ReaderTypography.getUiStyle();
        final geometric = ReaderTypography.getGeometricStyle();

        // UI style uses -0.2, geometric uses 0.0
        expect(ui.letterSpacing, lessThan(geometric.letterSpacing!));
        expect(ui.letterSpacing, -0.2);
        expect(geometric.letterSpacing, 0.0);
      });
    });
  });
}
