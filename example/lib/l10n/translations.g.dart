/// Generated file. Do not edit.
///
/// Source: lib/l10n
/// To regenerate, run: `dart run slang`
///
/// Locales: 10
/// Strings: 590 (59 per locale)
///
/// Built on 2026-06-25 at 04:51 UTC

// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'package:slang_flutter/slang_flutter.dart';
export 'package:slang_flutter/slang_flutter.dart';

import 'translations_es.g.dart' deferred as l_es;
import 'translations_fil.g.dart' deferred as l_fil;
import 'translations_fr.g.dart' deferred as l_fr;
import 'translations_id.g.dart' deferred as l_id;
import 'translations_ja.g.dart' deferred as l_ja;
import 'translations_ko.g.dart' deferred as l_ko;
import 'translations_pt.g.dart' deferred as l_pt;
import 'translations_zh.g.dart' deferred as l_zh;
import 'translations_pt_BR.g.dart' deferred as l_pt_BR;
part 'translations_en.g.dart';

/// Supported locales.
///
/// Usage:
/// - LocaleSettings.setLocale(AppLocale.en) // set locale
/// - Locale locale = AppLocale.en.flutterLocale // get flutter locale from enum
/// - if (LocaleSettings.currentLocale == AppLocale.en) // locale check
enum AppLocale with BaseAppLocale<AppLocale, Translations> {
	en(languageCode: 'en'),
	es(languageCode: 'es'),
	fil(languageCode: 'fil'),
	fr(languageCode: 'fr'),
	id(languageCode: 'id'),
	ja(languageCode: 'ja'),
	ko(languageCode: 'ko'),
	pt(languageCode: 'pt'),
	zh(languageCode: 'zh'),
	ptBr(languageCode: 'pt', countryCode: 'BR');

	const AppLocale({
		required this.languageCode,
		this.scriptCode, // ignore: unused_element, unused_element_parameter
		this.countryCode, // ignore: unused_element, unused_element_parameter
	});

	@override final String languageCode;
	@override final String? scriptCode;
	@override final String? countryCode;

	@override
	Future<Translations> build({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) async {
		switch (this) {
			case AppLocale.en:
				return TranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.es:
				await l_es.loadLibrary();
				return l_es.TranslationsEs(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.fil:
				await l_fil.loadLibrary();
				return l_fil.TranslationsFil(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.fr:
				await l_fr.loadLibrary();
				return l_fr.TranslationsFr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.id:
				await l_id.loadLibrary();
				return l_id.TranslationsId(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ja:
				await l_ja.loadLibrary();
				return l_ja.TranslationsJa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ko:
				await l_ko.loadLibrary();
				return l_ko.TranslationsKo(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.pt:
				await l_pt.loadLibrary();
				return l_pt.TranslationsPt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.zh:
				await l_zh.loadLibrary();
				return l_zh.TranslationsZh(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ptBr:
				await l_pt_BR.loadLibrary();
				return l_pt_BR.TranslationsPtBr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	@override
	Translations buildSync({
		Map<String, Node>? overrides,
		PluralResolver? cardinalResolver,
		PluralResolver? ordinalResolver,
	}) {
		switch (this) {
			case AppLocale.en:
				return TranslationsEn(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.es:
				return l_es.TranslationsEs(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.fil:
				return l_fil.TranslationsFil(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.fr:
				return l_fr.TranslationsFr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.id:
				return l_id.TranslationsId(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ja:
				return l_ja.TranslationsJa(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ko:
				return l_ko.TranslationsKo(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.pt:
				return l_pt.TranslationsPt(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.zh:
				return l_zh.TranslationsZh(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
			case AppLocale.ptBr:
				return l_pt_BR.TranslationsPtBr(
					overrides: overrides,
					cardinalResolver: cardinalResolver,
					ordinalResolver: ordinalResolver,
				);
		}
	}

	/// Gets current instance managed by [LocaleSettings].
	Translations get translations => LocaleSettings.instance.getTranslations(this);
}

/// Method A: Simple
///
/// No rebuild after locale change.
/// Translation happens during initialization of the widget (call of t).
/// Configurable via 'translate_var'.
///
/// Usage:
/// String a = t.someKey.anotherKey;
/// String b = t['someKey.anotherKey']; // Only for edge cases!
Translations get t => LocaleSettings.instance.currentTranslations;

/// Method B: Advanced
///
/// All widgets using this method will trigger a rebuild when locale changes.
/// Use this if you have e.g. a settings page where the user can select the locale during runtime.
///
/// Step 1:
/// wrap your App with
/// TranslationProvider(
/// 	child: MyApp()
/// );
///
/// Step 2:
/// final t = Translations.of(context); // Get t variable.
/// String a = t.someKey.anotherKey; // Use t variable.
/// String b = t['someKey.anotherKey']; // Only for edge cases!
class TranslationProvider extends BaseTranslationProvider<AppLocale, Translations> {
	TranslationProvider({required super.child}) : super(settings: LocaleSettings.instance);

	static InheritedLocaleData<AppLocale, Translations> of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context);
}

/// Method B shorthand via [BuildContext] extension method.
/// Configurable via 'translate_var'.
///
/// Usage (e.g. in a widget's build method):
/// context.t.someKey.anotherKey
extension BuildContextTranslationsExtension on BuildContext {
	Translations get t => TranslationProvider.of(this).translations;
}

/// Manages all translation instances and the current locale
class LocaleSettings extends BaseFlutterLocaleSettings<AppLocale, Translations> {
	LocaleSettings._() : super(
		utils: AppLocaleUtils.instance,
		lazy: true,
	);

	static final instance = LocaleSettings._();

	// static aliases (checkout base methods for documentation)
	static AppLocale get currentLocale => instance.currentLocale;
	static Stream<AppLocale> getLocaleStream() => instance.getLocaleStream();
	static Future<AppLocale> setLocale(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocale(locale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<AppLocale> setLocaleRaw(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRaw(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static Future<AppLocale> useDeviceLocale() => instance.useDeviceLocale();
	static Future<void> setPluralResolver({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolver(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);

	// synchronous versions
	static AppLocale setLocaleSync(AppLocale locale, {bool? listenToDeviceLocale = false}) => instance.setLocaleSync(locale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale setLocaleRawSync(String rawLocale, {bool? listenToDeviceLocale = false}) => instance.setLocaleRawSync(rawLocale, listenToDeviceLocale: listenToDeviceLocale);
	static AppLocale useDeviceLocaleSync() => instance.useDeviceLocaleSync();
	static void setPluralResolverSync({String? language, AppLocale? locale, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver}) => instance.setPluralResolverSync(
		language: language,
		locale: locale,
		cardinalResolver: cardinalResolver,
		ordinalResolver: ordinalResolver,
	);
}

/// Provides utility functions without any side effects.
class AppLocaleUtils extends BaseAppLocaleUtils<AppLocale, Translations> {
	AppLocaleUtils._() : super(
		baseLocale: AppLocale.en,
		locales: AppLocale.values,
	);

	static final instance = AppLocaleUtils._();

	// static aliases (checkout base methods for documentation)
	static AppLocale parse(String rawLocale) => instance.parse(rawLocale);
	static AppLocale parseLocaleParts({required String languageCode, String? scriptCode, String? countryCode}) => instance.parseLocaleParts(languageCode: languageCode, scriptCode: scriptCode, countryCode: countryCode);
	static AppLocale findDeviceLocale() => instance.findDeviceLocale();
	static List<Locale> get supportedLocales => instance.supportedLocales;
	static List<String> get supportedLocalesRaw => instance.supportedLocalesRaw;
}
