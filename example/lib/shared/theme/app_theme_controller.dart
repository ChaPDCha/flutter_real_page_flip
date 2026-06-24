import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../firebase/firebase_service.dart';

import '../../features/sync/application/sync_provider.dart';
import 'reader_theme.dart';

part 'app_theme_controller.g.dart';

const _appThemeKey = 'app_theme';
const _legacyReaderSettingsKey = 'reader_settings';

@Riverpod(keepAlive: true)
class AppThemeController extends _$AppThemeController {
  @override
  ReaderThemeType build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _loadTheme(prefs.getString(_appThemeKey));
  }

  Future<void> setTheme(ReaderThemeType themeType) async {
    if (state == themeType) return;

    state = themeType;
    unawaited(FirebaseService.logThemeChanged(themeType.name));
    await ref
        .read(sharedPreferencesProvider)
        .setString(_appThemeKey, themeType.name);
  }

  ReaderThemeType _loadTheme(String? savedTheme) {
    if (savedTheme != null) {
      return ReaderThemeType.values.firstWhere(
        (type) => type.name == savedTheme,
        orElse: () => ReaderThemeType.charcoal,
      );
    }

    return _migrateLegacyTheme() ?? ReaderThemeType.charcoal;
  }

  ReaderThemeType? _migrateLegacyTheme() {
    final legacyJson = ref
        .read(sharedPreferencesProvider)
        .getString(_legacyReaderSettingsKey);
    if (legacyJson == null) return null;

    try {
      final map = json.decode(legacyJson) as Map<String, dynamic>;
      final themeStr = map['themeType'] as String?;
      return switch (themeStr) {
        'cream' => ReaderThemeType.cream,
        'charcoal' => ReaderThemeType.charcoal,
        'sepia' => ReaderThemeType.cream,
        _ => null,
      };
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Legacy theme migration');
      return null;
    }
  }
}
