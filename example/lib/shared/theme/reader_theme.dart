import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ReaderThemeType {
  cream,
  charcoal,
}

class ReaderThemeData {
  final ReaderThemeType type;
  final Color backgroundColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;
  final Color dividerColor;
  final Color panelColor;

  const ReaderThemeData({
    required this.type,
    required this.backgroundColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.accentColor,
    required this.dividerColor,
    required this.panelColor,
  });

  static const cream = ReaderThemeData(
    type: ReaderThemeType.cream,
    backgroundColor: Color(0xFFF9F6F0), // Warm cream/off-white paper
    textColor: Color(0xFF2C2A29), // Charcoal text
    secondaryTextColor: Color(0xFF706D6B), // Muted warm grey
    accentColor: Color(0xFF8C6239), // Soft leather brown
    dividerColor: Color(0xFFE5DEC9), // Muted gold/beige
    panelColor: Color(0xFFF2ECE0), // Slightly darker cream for settings panel
  );

  static const charcoal = ReaderThemeData(
    type: ReaderThemeType.charcoal,
    backgroundColor: Color(0xFF1E1E1E), // Low-contrast black/dark grey
    textColor: Color(0xFFE0E0E0), // Soft off-white
    secondaryTextColor: Color(0xFF888888), // Slate grey
    accentColor: Color(0xFFD4AF37), // Soft gold accent
    dividerColor: Color(0xFF2D2D2D), // Dark grey divider
    panelColor: Color(0xFF252525), // Solid dark grey for panel
  );

  static ReaderThemeData get(ReaderThemeType type) {
    switch (type) {
      case ReaderThemeType.cream:
        return cream;
      case ReaderThemeType.charcoal:
        return charcoal;
    }
  }

  bool get isDark => type == ReaderThemeType.charcoal;

  Color get buttonForegroundColor => isDark ? Colors.black : Colors.white;

  ShadThemeData toShadTheme() {
    return ShadThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryButtonTheme: ShadButtonTheme(
        backgroundColor: accentColor,
        foregroundColor: buttonForegroundColor,
      ),
    );
  }
}
