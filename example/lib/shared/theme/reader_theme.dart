import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum ReaderThemeType { cream, charcoal }

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
    backgroundColor: Color(
      0xFF0A0A0B,
    ), // Low-contrast warm black for night reading
    textColor: Color(
      0xFFC8C5C0,
    ), // Low-glare warm silver-sand (neutralizes eye strain)
    secondaryTextColor: Color(0xFF76757A), // Muted grey
    accentColor: Color(0xFFC5A880), // Luxury champagne-bronze
    dividerColor: Color(0xFF1C1C1E), // Soft dark divider
    panelColor: Color(0xFF141416), // Surface panel
  );

  static const charcoal = ReaderThemeData(
    type: ReaderThemeType.charcoal,
    backgroundColor: Color(0xFF0A0A0B), // Low-contrast warm black
    textColor: Color(0xFFC8C5C0), // Low-glare warm silver-sand
    secondaryTextColor: Color(0xFF76757A), // Muted grey
    accentColor: Color(0xFFC5A880),
    dividerColor: Color(0xFF1C1C1E),
    panelColor: Color(0xFF141416),
  );

  static ReaderThemeData get(ReaderThemeType type) {
    return charcoal; // Exclusively dark mode
  }

  bool get isDark => type == ReaderThemeType.charcoal;

  Color get buttonForegroundColor =>
      Colors.black; // High-contrast black on champagne gold

  static const Color errorColor = Color(0xFFC65D5D); // Premium ruby/rose error

  static const Color successColor = Color(0xFF8CAE7A); // Muted sage success

  Color get shadowColor => Colors.black.withValues(alpha: 0.4);

  Color get coverBackgroundColor =>
      isDark ? const Color(0xFF2A2A2A) : panelColor;

  Color get coverBorderColor => isDark ? const Color(0xFF3A3A3A) : dividerColor;

  Color get coverTitleColor => isDark ? const Color(0xFFD0D0D0) : textColor;

  ThemeData toMaterialTheme() {
    const brightness = Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accentColor,
        onPrimary: buttonForegroundColor,
        secondary: accentColor,
        onSecondary: buttonForegroundColor,
        surface: panelColor,
        onSurface: textColor,
        error: errorColor,
        onError: Colors.white,
      ),
      dialogTheme: DialogThemeData(backgroundColor: panelColor),
      dividerColor: dividerColor,
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: secondaryTextColor),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        labelLarge: TextStyle(color: textColor),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentColor),
      ),
    );
  }

  ShadThemeData toShadTheme() {
    return ShadThemeData(
      brightness: Brightness.dark,
      primaryButtonTheme: ShadButtonTheme(
        backgroundColor: accentColor,
        foregroundColor: buttonForegroundColor,
      ),
    );
  }
}
