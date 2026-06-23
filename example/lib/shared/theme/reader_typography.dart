import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReaderTypography {
  static bool get _isTest =>
      !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  // Editorial UI Font (Sans-Serif)
  static TextStyle getUiStyle({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? -0.2,
        fontFamily: 'sans-serif',
      );
    }
    return GoogleFonts.notoSansKr(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing ?? -0.2,
    );
  }

  // Modern Geometric UI Font for English text/numbers
  static TextStyle getGeometricStyle({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing ?? 0.0,
        fontFamily: 'sans-serif',
      );
    }
    return GoogleFonts.outfit(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing ?? 0.0,
    );
  }

  // Premium typography scale for the e-book viewer
  static TextStyle getBookStyle({
    required double fontSize,
    required Color color,
    double lineHeight = 1.6,
    String? fontFamily,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: fontSize,
        height: lineHeight,
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
        fontFamily: fontFamily == 'serif' ? 'serif' : 'sans-serif',
      );
    }
    if (fontFamily == 'serif') {
      return GoogleFonts.notoSerifKr(
        fontSize: fontSize,
        height: lineHeight,
        color: color,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.2,
      );
    }
    // Default to clean Noto Sans KR for modern sans-serif reading
    return GoogleFonts.notoSansKr(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.2,
    );
  }

  static TextStyle getChapterHeaderStyle({
    required double baseFontSize,
    required Color color,
    String? fontFamily,
  }) {
    if (_isTest) {
      return TextStyle(
        fontSize: baseFontSize * 1.4,
        height: 1.4,
        color: color,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        fontFamily: fontFamily == 'serif' ? 'serif' : 'sans-serif',
      );
    }
    if (fontFamily == 'serif') {
      return GoogleFonts.notoSerifKr(
        fontSize: baseFontSize * 1.4,
        height: 1.4,
        color: color,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      );
    }
    return GoogleFonts.notoSansKr(
      fontSize: baseFontSize * 1.4,
      height: 1.4,
      color: color,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );
  }
}
