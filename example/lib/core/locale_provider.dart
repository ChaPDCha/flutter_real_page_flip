import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/translations.g.dart';

const localePrefKey = 'app_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(LocaleSettings.instance.currentLocale.flutterLocale);

  Future<void> setLocale(Locale locale) async {
    final raw = locale.countryCode != null
        ? '${locale.languageCode}_${locale.countryCode}'
        : locale.languageCode;
    final appLocale = LocaleSettings.setLocaleRawSync(raw);
    state = appLocale.flutterLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localePrefKey, raw);
  }
}
