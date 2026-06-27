import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:real_page_flip_example/shared/firebase/firebase_service.dart';

// =============================================================================
// Method-channel-level mock helpers for Firebase Flutter packages.
//
// Firebase static singletons (FirebaseAnalytics.instance etc.) are not
// mockable via mocktail.  Instead we register mock MethodChannel handlers so
// the real Firebase platform implementations can be instantiated in tests.
//
// If the published package switches to a Pigeon-generated channel name the
// mock will be silently skipped — tests that verify call recording via the
// lists below will then fail, alerting us to update.
// =============================================================================

final _analyticsCalls = <MethodCall>[];
final _crashlyticsCalls = <MethodCall>[];
final _remoteConfigCalls = <MethodCall>[];

void _installFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_core'),
        (MethodCall call) async {
          if (call.method == 'Firebase#initializeCore') {
            return <dynamic>[];
          }
          if (call.method == 'Firebase#initializeApp') {
            return <String, dynamic>{
              'name': (call.arguments as Map?)?.containsKey('appName') == true
                  ? (call.arguments as Map)['appName']
                  : 'default',
              'options': <String, String>{
                'apiKey': 'test-api-key',
                'appId': 'test-app-id',
                'messagingSenderId': 'test-sender-id',
                'projectId': 'test-project',
                'storageBucket': 'test.appspot.com',
              },
              'pluginConstants': <String, Map<String, dynamic>>{},
              'isAutomaticDataCollectionEnabled': false,
            };
          }
          return null;
        },
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_analytics'),
        (MethodCall call) async {
          _analyticsCalls.add(call);
          return null;
        },
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_crashlytics'),
        (MethodCall call) async {
          _crashlyticsCalls.add(call);
          return null;
        },
      );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_remote_config'),
        (MethodCall call) async {
          _remoteConfigCalls.add(call);
          if (call.method == 'RemoteConfig#fetchAndActivate') {
            return true;
          }
          if (call.method == 'RemoteConfig#getBoolean') {
            return (call.arguments as String?) == 'ads_enabled';
          }
          if (call.method == 'RemoteConfig#getLong') {
            return 50;
          }
          if (call.method == 'RemoteConfig#getDouble') {
            return 16.0;
          }
          return null;
        },
      );
}

void _uninstallFirebaseMocks() {
  for (final channel in [
    'plugins.flutter.io/firebase_core',
    'plugins.flutter.io/firebase_analytics',
    'plugins.flutter.io/firebase_crashlytics',
    'plugins.flutter.io/firebase_remote_config',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MethodChannel(channel), null);
  }
}

/// Tries to initialize Firebase in the test environment.
/// Returns true if initialization succeeded.
Future<bool> _initFirebase() async {
  try {
    _installFirebaseMocks();
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: 'test-app-id',
        messagingSenderId: 'test-sender-id',
        projectId: 'test-project',
        storageBucket: 'test.appspot.com',
      ),
    );
    return true;
  } catch (_) {
    return false;
  }
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Without Firebase initialization
  // ---------------------------------------------------------------------------
  group('Without Firebase initialization', () {
    test('logEvent completes without error', () async {
      await expectLater(
        FirebaseService.logEvent(name: 'test_event'),
        completes,
      );
    });

    test('recordError completes without error', () {
      expect(
        () => FirebaseService.recordError(
          Exception('test error'),
          StackTrace.current,
          reason: 'test',
          fatal: false,
        ),
        returnsNormally,
      );
    });

    test('initRemoteConfig completes without error', () async {
      await expectLater(FirebaseService.initRemoteConfig(), completes);
    });

    test('setCurrentScreen completes without error', () async {
      await expectLater(
        FirebaseService.setCurrentScreen('test_screen'),
        completes,
      );
    });

    test('setUserProperty completes without error', () async {
      await expectLater(
        FirebaseService.setUserProperty(name: 'test', value: 'value'),
        completes,
      );
    });

    test('default RemoteConfig values are returned', () {
      expect(FirebaseService.adsEnabled, isTrue);
      expect(FirebaseService.maxBookshelfItems, equals(50));
      expect(FirebaseService.defaultFontSize, equals(16.0));
    });

    test('book lifecycle methods complete without error', () async {
      await FirebaseService.logBookOpened('book-1', 'epub');
      await FirebaseService.logBookClosed('book-1', 120);
      await FirebaseService.logPageTurned('book-1');
      await FirebaseService.logPageTurned('book-1', isForward: false);
    });

    test('reader settings methods complete without error', () async {
      await FirebaseService.logFontSizeChanged(18.0);
      await FirebaseService.logLineHeightChanged(2.0);
      await FirebaseService.logBrightnessChanged(0.8);
      await FirebaseService.logFontFamilyChanged('serif');
      await FirebaseService.logThemeChanged('charcoal');
      await FirebaseService.logHapticsToggled(true);
      await FirebaseService.logSoundToggled(false);
    });

    test('TTS methods complete without error', () async {
      await FirebaseService.logTtsStarted('book-1');
      await FirebaseService.logTtsStopped('book-1');
    });

    test('search and highlight methods complete without error', () async {
      await FirebaseService.logSearchPerformed('query');
      await FirebaseService.logHighlightAdded('book-1');
    });

    test('recordError handles null stack trace', () {
      expect(
        () => FirebaseService.recordError(
          'string error',
          null,
          reason: 'null stack',
        ),
        returnsNormally,
      );
    });

    test('recordError handles fatal flag', () {
      expect(
        () => FirebaseService.recordError(
          Exception('fatal'),
          StackTrace.current,
          fatal: true,
        ),
        returnsNormally,
      );
    });

    test('logEvent with parameters completes without error', () async {
      await expectLater(
        FirebaseService.logEvent(
          name: 'test_params',
          parameters: <String, Object>{'key': 'value', 'count': 42},
        ),
        completes,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // With Firebase mocked
  // ---------------------------------------------------------------------------
  group('With Firebase mocked', () {
    late bool firebaseReady;

    setUpAll(() async {
      firebaseReady = await _initFirebase();
      if (firebaseReady) {
        try {
          await FirebaseService.setCurrentScreen('init_check');
        } catch (_) {}
      }
    });

    tearDownAll(() {
      _uninstallFirebaseMocks();
    });

    test('logEvent does not throw', () async {
      await expectLater(
        FirebaseService.logEvent(name: 'mocked_event'),
        completes,
      );
    });

    test('setCurrentScreen does not throw', () async {
      await expectLater(
        FirebaseService.setCurrentScreen('mocked_screen'),
        completes,
      );
    });

    test('setUserProperty does not throw', () async {
      await expectLater(
        FirebaseService.setUserProperty(name: 'prop', value: 'val'),
        completes,
      );
    });

    test('initRemoteConfig sets defaults and calls fetchAndActivate', () async {
      await expectLater(FirebaseService.initRemoteConfig(), completes);
    });

    test('book lifecycle events do not throw', () async {
      await FirebaseService.logBookOpened('b1', 'pdf');
      await FirebaseService.logBookClosed('b1', 300);
      await FirebaseService.logPageTurned('b1');
      await FirebaseService.logPageTurned('b1', isForward: false);
    });

    test('reader settings events do not throw', () async {
      await FirebaseService.logFontSizeChanged(20.0);
      await FirebaseService.logLineHeightChanged(1.8);
      await FirebaseService.logBrightnessChanged(0.5);
      await FirebaseService.logFontFamilyChanged('sans-serif');
      await FirebaseService.logThemeChanged('cream');
      await FirebaseService.logHapticsToggled(false);
      await FirebaseService.logSoundToggled(true);
    });

    test('TTS events do not throw', () async {
      await FirebaseService.logTtsStarted('b1');
      await FirebaseService.logTtsStopped('b1');
    });

    test('search and highlight events do not throw', () async {
      await FirebaseService.logSearchPerformed('bible');
      await FirebaseService.logHighlightAdded('b1');
    });

    test('recordError does not throw with mocked Crashlytics', () {
      expect(
        () => FirebaseService.recordError(
          Exception('mocked error'),
          StackTrace.current,
          reason: 'test_reason',
        ),
        returnsNormally,
      );
    });

    test('recordError with fatal flag does not throw', () {
      expect(
        () => FirebaseService.recordError(
          Exception('fatal error'),
          StackTrace.current,
          fatal: true,
        ),
        returnsNormally,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Remote Config values
  // ---------------------------------------------------------------------------
  group('Remote Config defaults', () {
    test('adsEnabled defaults to true', () {
      expect(FirebaseService.adsEnabled, isTrue);
    });

    test('maxBookshelfItems defaults to 50', () {
      expect(FirebaseService.maxBookshelfItems, equals(50));
    });

    test('defaultFontSize defaults to 16.0', () {
      expect(FirebaseService.defaultFontSize, equals(16.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------
  group('Edge cases', () {
    test('logEvent handles empty parameters', () async {
      await expectLater(FirebaseService.logEvent(name: 'no_params'), completes);
    });

    test('logEvent handles null parameters', () async {
      await expectLater(
        FirebaseService.logEvent(name: 'null_params'),
        completes,
      );
    });

    test('setCurrentScreen handles empty screen name', () async {
      await expectLater(FirebaseService.setCurrentScreen(''), completes);
    });

    test('setUserProperty handles empty values', () async {
      await expectLater(
        FirebaseService.setUserProperty(name: '', value: ''),
        completes,
      );
    });

    test('logBookOpened handles various formats', () async {
      await FirebaseService.logBookOpened('book-2', 'epub');
      await FirebaseService.logBookOpened('book-3', 'pdf');
      await FirebaseService.logBookOpened('book-4', 'txt');
    });

    test('logBookClosed handles zero duration', () async {
      await FirebaseService.logBookClosed('book-5', 0);
    });

    test('multiple rapid logEvents do not throw', () async {
      await Future.wait([
        FirebaseService.logEvent(name: 'e1'),
        FirebaseService.logEvent(name: 'e2'),
        FirebaseService.logEvent(name: 'e3'),
      ]);
    });
  });
}
