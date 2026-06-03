import 'package:flutter/material.dart';

class ReaderTypography {
  // Premium typography scale for the e-book viewer
  static TextStyle getBookStyle({
    required double fontSize,
    required Color color,
    double lineHeight = 1.6,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontFamily: fontFamily,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.2, // Tighter letter spacing for better Korean/English readability
    );
  }

  static TextStyle getChapterHeaderStyle({
    required double baseFontSize,
    required Color color,
    String? fontFamily,
  }) {
    return TextStyle(
      fontSize: baseFontSize * 1.4,
      height: 1.4,
      color: color,
      fontFamily: fontFamily,
      fontWeight: FontWeight.bold,
      letterSpacing: -0.5,
    );
  }
}
