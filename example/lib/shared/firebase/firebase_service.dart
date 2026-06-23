import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Central Firebase facade — Analytics + Remote Config.
///
/// All public methods are safe to call before Firebase is initialized;
/// they silently no-op when Firebase is unavailable (test environment,
/// restricted platform, etc.).
class FirebaseService {
  FirebaseService._();

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Lazy — returns null if Firebase is not yet initialized.
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  /// Lazy — returns null if Firebase Remote Config is not yet initialized.
  static FirebaseRemoteConfig? get _remoteConfig {
    try {
      return FirebaseRemoteConfig.instance;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Fetch and activate remote config defaults. Call once at app start.
  static Future<void> initRemoteConfig() async {
    final config = _remoteConfig;
    if (config == null) return;

    await config.setDefaults(const {
      'ads_enabled': true,
      'max_bookshelf_items': 50,
      'default_font_size': 16.0,
      'default_line_height': 1.6,
    });

    try {
      await config.fetchAndActivate();
    } catch (_) {
      // Use defaults if fetch fails.
    }
  }

  // ---------------------------------------------------------------------------
  // Remote Config helpers
  // ---------------------------------------------------------------------------

  static bool get adsEnabled => _remoteConfig?.getBool('ads_enabled') ?? true;

  static int get maxBookshelfItems =>
      _remoteConfig?.getInt('max_bookshelf_items') ?? 50;

  static double get defaultFontSize =>
      _remoteConfig?.getDouble('default_font_size') ?? 16.0;

  // ---------------------------------------------------------------------------
  // Screen tracking
  // ---------------------------------------------------------------------------

  static Future<void> setCurrentScreen(String screenName) =>
      _analytics?.logScreenView(screenName: screenName) ?? Future.value();

  // ---------------------------------------------------------------------------
  // User properties
  // ---------------------------------------------------------------------------

  static Future<void> setUserProperty({
    required String name,
    required String value,
  }) => _analytics?.setUserProperty(name: name, value: value) ?? Future.value();

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) =>
      _analytics?.logEvent(name: name, parameters: parameters) ??
      Future.value();

  // -- Book lifecycle --------------------------------------------------------

  static Future<void> logBookOpened(String bookId, String format) => logEvent(
    name: 'book_opened',
    parameters: {'book_id': bookId, 'format': format},
  );

  static Future<void> logBookClosed(String bookId, int durationSec) => logEvent(
    name: 'book_closed',
    parameters: {'book_id': bookId, 'duration_sec': durationSec},
  );

  static Future<void> logPageTurned(String bookId, {bool isForward = true}) =>
      logEvent(
        name: 'page_turned',
        parameters: {
          'book_id': bookId,
          'direction': isForward ? 'forward' : 'backward',
        },
      );

  // -- Reader settings -------------------------------------------------------

  static Future<void> logFontSizeChanged(double newSize) =>
      logEvent(name: 'font_size_changed', parameters: {'value': newSize});

  static Future<void> logLineHeightChanged(double newHeight) =>
      logEvent(name: 'line_height_changed', parameters: {'value': newHeight});

  static Future<void> logBrightnessChanged(double brightness) =>
      logEvent(name: 'brightness_changed', parameters: {'value': brightness});

  static Future<void> logFontFamilyChanged(String family) =>
      logEvent(name: 'font_family_changed', parameters: {'family': family});

  static Future<void> logThemeChanged(String theme) =>
      logEvent(name: 'theme_changed', parameters: {'theme': theme});

  static Future<void> logHapticsToggled(bool enabled) =>
      logEvent(name: 'haptics_toggled', parameters: {'enabled': enabled});

  static Future<void> logSoundToggled(bool enabled) =>
      logEvent(name: 'sound_toggled', parameters: {'enabled': enabled});

  // -- TTS -------------------------------------------------------------------

  static Future<void> logTtsStarted(String bookId) =>
      logEvent(name: 'tts_started', parameters: {'book_id': bookId});

  static Future<void> logTtsStopped(String bookId) =>
      logEvent(name: 'tts_stopped', parameters: {'book_id': bookId});

  // -- Search / Highlight ----------------------------------------------------

  static Future<void> logSearchPerformed(String query) => logEvent(
    name: 'search_performed',
    parameters: {'query_length': query.length},
  );

  static Future<void> logHighlightAdded(String bookId) =>
      logEvent(name: 'highlight_added', parameters: {'book_id': bookId});
}
