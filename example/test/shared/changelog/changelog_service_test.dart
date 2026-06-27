import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/shared/changelog/changelog_service.dart';

// ---------------------------------------------------------------------------
// Mock classes for dart:io HttpClient
// ---------------------------------------------------------------------------

class _MockHttpClient extends Mock implements HttpClient {}

class _MockHttpClientRequest extends Mock implements HttpClientRequest {}

class _MockHttpClientResponse extends Mock implements HttpClientResponse {}

class _MockHttpHeaders extends Mock implements HttpHeaders {}

// ---------------------------------------------------------------------------
// HttpOverrides that returns a controllable mock client
// ---------------------------------------------------------------------------

class _MockHttpOverrides extends HttpOverrides {
  final HttpClient Function() clientFactory;
  _MockHttpOverrides(this.clientFactory);

  @override
  HttpClient createHttpClient(SecurityContext? context) => clientFactory();
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _kCacheKey = 'cached_remote_changelog';
const _kCacheTimeKey = 'cached_remote_changelog_at';
const _kLastSeenKey = 'last_seen_changelog_version';

final _sampleChangelogEntry = <String, dynamic>{
  'version': '2.0.0+40',
  'versionName': '2.0.0',
  'date': '2026-07-01',
  'ko': <String, dynamic>{
    'changes': <String>['한국어 변경사항'],
  },
  'en': <String, dynamic>{
    'changes': <String>['English change'],
  },
};

final _sampleChangelogList = [_sampleChangelogEntry];

int _hoursAgoTimestamp(int hours) {
  return DateTime.now().millisecondsSinceEpoch - hours * 3600000;
}

// ---------------------------------------------------------------------------
// Helper: pump a MaterialApp whose button triggers showIfNew
// ---------------------------------------------------------------------------

Future<SharedPreferences> pumpShowIfNewButton({
  required WidgetTester tester,
  required Map<String, Object> prefsValues,
  Locale locale = const Locale('en', 'US'),
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en', 'US'), Locale('ko', 'KR')],
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () =>
              ChangelogService.showIfNew(context: context, prefs: prefs),
          child: const Text('Check'),
        ),
      ),
    ),
  );
  await tester.pump();

  return prefs;
}

/// Helper to set up mock HTTP that returns a given JSON list body with a
/// given status code.
void _setupMockHttp(int statusCode, String body) {
  final mockClient = _MockHttpClient();
  final mockRequest = _MockHttpClientRequest();
  final mockResponse = _MockHttpClientResponse();
  final mockHeaders = _MockHttpHeaders();

  HttpOverrides.global = _MockHttpOverrides(() => mockClient);

  when(() => mockClient.getUrl(any())).thenAnswer((_) async => mockRequest);
  when(() => mockRequest.headers).thenReturn(mockHeaders);
  when(() => mockRequest.close()).thenAnswer((_) async => mockResponse);
  when(() => mockResponse.statusCode).thenReturn(statusCode);
  when(() => mockResponse.transform(any())).thenAnswer((_) {
    return Stream<String>.value(body);
  });
}

/// Helper that sets up a mock HTTP client that throws on getUrl.
void _setupMockHttpError(String message) {
  final mockClient = _MockHttpClient();

  HttpOverrides.global = _MockHttpOverrides(() => mockClient);

  when(() => mockClient.getUrl(any()))
      .thenThrow(HttpException(message));
}

void _cleanupMockHttp() {
  HttpOverrides.global = null;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    _cleanupMockHttp();
  });

  // =========================================================================
  // showIfNew — dialog display logic
  // =========================================================================

  group('showIfNew', () {
    testWidgets('shows dialog with correct title and changes for new version',
        (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("What's New in v2.0.0"), findsOneWidget);
      expect(find.text('English change'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('marks version as seen after showing dialog', (tester) async {
      final prefs = await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(prefs.getString(_kLastSeenKey), equals('2.0.0+40'));
    });

    testWidgets('does not show dialog when version already seen',
        (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kLastSeenKey: '2.0.0+40',
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("What's New in v2.0.0"), findsNothing);
      expect(find.text('English change'), findsNothing);
    });

    testWidgets('does not show dialog when changes are empty',
        (tester) async {
      final emptyEntry = <String, dynamic>{
        'version': '3.0.0+50',
        'versionName': '3.0.0',
        'en': <String, dynamic>{'changes': <String>[]},
      };

      final prefs = await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(emptyEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AlertDialog), findsNothing);
      // Version should NOT be saved since dialog was not shown
      expect(prefs.getString(_kLastSeenKey), isNull);
    });

    testWidgets('returns early when changelog data is null', (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{},
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows Korean dialog when locale is ko', (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        locale: const Locale('ko', 'KR'),
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('v2.0.0 새로운 기능'), findsOneWidget);
      expect(find.text('한국어 변경사항'), findsOneWidget);
      expect(find.text('확인'), findsOneWidget);
    });

    testWidgets('falls back to English when locale not available',
        (tester) async {
      final entry = <String, dynamic>{
        'version': '4.0.0+60',
        'versionName': '4.0.0',
        'en': <String, dynamic>{'changes': <String>['Fallback change']},
        // No 'fr' key
      };

      await pumpShowIfNewButton(
        tester: tester,
        locale: const Locale('fr', 'FR'),
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(entry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("What's New in v4.0.0"), findsOneWidget);
      expect(find.text('Fallback change'), findsOneWidget);
    });
  });

  // =========================================================================
  // Dialog — Done / 확인 dismiss behavior
  // =========================================================================

  group('dialog dismiss behavior', () {
    testWidgets('Done button dismisses dialog', (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Done'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsNothing);
      expect(find.text("What's New in v2.0.0"), findsNothing);
    });

    testWidgets('확인 button dismisses Korean dialog', (tester) async {
      await pumpShowIfNewButton(
        tester: tester,
        locale: const Locale('ko', 'KR'),
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1),
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('확인'), findsOneWidget);
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();

      expect(find.text('확인'), findsNothing);
    });
  });

  // =========================================================================
  // Cache behavior
  // =========================================================================

  group('cache behavior', () {
    testWidgets('uses fresh cache from SharedPreferences without network call',
        (tester) async {
      // Set up mock HTTP that would fail the test if called
      final mockClient = _MockHttpClient();
      HttpOverrides.global = _MockHttpOverrides(() => mockClient);

      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(1), // 1 hour old — still fresh
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("What's New in v2.0.0"), findsOneWidget);
      expect(find.text('English change'), findsOneWidget);

      // getUrl should NEVER be called because cache was fresh
      verifyNever(() => mockClient.getUrl(any()));

      _cleanupMockHttp();
    });

    testWidgets(
        'fetches from network when cache is stale and updates SharedPreferences',
        (tester) async {
      final updatedEntry = <String, dynamic>{
        'version': '5.0.0+70',
        'versionName': '5.0.0',
        'en': <String, dynamic>{'changes': <String>['Fetched from network']},
      };
      _setupMockHttp(200, json.encode([updatedEntry]));

      final prefs = await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(48), // 48 hours = stale
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Dialog shows NETWORK data, not the stale cached data
      expect(find.text("What's New in v5.0.0"), findsOneWidget);
      expect(find.text('Fetched from network'), findsOneWidget);

      // Cache was updated in SharedPreferences
      final cachedJson = prefs.getString(_kCacheKey);
      expect(cachedJson, isNotNull);
      final cached = json.decode(cachedJson!) as Map<String, dynamic>;
      expect(cached['version'], equals('5.0.0+70'));

      _cleanupMockHttp();
    });

    testWidgets('fetches from network when no cache exists', (tester) async {
      _setupMockHttp(200, json.encode(_sampleChangelogList));

      final prefs = await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{},
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("What's New in v2.0.0"), findsOneWidget);

      // Verify cache was written
      final cachedJson = prefs.getString(_kCacheKey);
      expect(cachedJson, isNotNull);
      final cached = json.decode(cachedJson!) as Map<String, dynamic>;
      expect(cached['version'], equals('2.0.0+40'));

      _cleanupMockHttp();
    });

    testWidgets('non-200 status code falls through to bundled fallback',
        (tester) async {
      _setupMockHttp(404, 'Not Found');

      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{},
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 404 -> falls through -> bundle not available in test -> no dialog
      expect(find.byType(AlertDialog), findsNothing);

      _cleanupMockHttp();
    });

    testWidgets('network exception is caught gracefully', (tester) async {
      _setupMockHttpError('Connection refused');

      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{},
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Exception caught, falls through, no dialog
      expect(find.byType(AlertDialog), findsNothing);

      _cleanupMockHttp();
    });

    testWidgets('returns null when cache stale, network fails, and no bundle',
        (tester) async {
      _setupMockHttp(500, 'Server Error');

      await pumpShowIfNewButton(
        tester: tester,
        prefsValues: <String, Object>{
          _kCacheKey: json.encode(_sampleChangelogEntry),
          _kCacheTimeKey: _hoursAgoTimestamp(48), // stale
        },
      );

      await tester.tap(find.text('Check'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Everything failed, no dialog
      expect(find.byType(AlertDialog), findsNothing);

      _cleanupMockHttp();
    });
  });

  // =========================================================================
  // ChangelogGate
  // =========================================================================

  group('ChangelogGate', () {
    testWidgets('renders simple child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ChangelogGate(child: Text('Gate Child')),
        ),
      );
      await tester.pump();
      // Let the post-frame callback fire
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Gate Child'), findsOneWidget);
    });

    testWidgets('renders complex child widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ChangelogGate(
            child: SizedBox(
              width: 200,
              height: 100,
              child: Center(child: Text('Complex Child')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Complex Child'), findsOneWidget);
    });

    testWidgets('does not throw when mounted after post-frame callback',
        (tester) async {
      // This verifies the gate's safety checks (mounted, _checked, etc.)
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          home: ChangelogGate(child: Text('Stability Check')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Stability Check'), findsOneWidget);
      // No crashes, no duplicate dialogs
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
