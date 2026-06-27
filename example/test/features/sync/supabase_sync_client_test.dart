import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:real_page_flip_example/features/sync/application/supabase_sync_client.dart';

// ---------------------------------------------------------------------------
// Mock types (for GoTrue, User, AuthResponse only)
// ---------------------------------------------------------------------------

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

class _MockAuthResponse extends Mock implements AuthResponse {}

// ---------------------------------------------------------------------------
// Fake PostgrestFilterBuilder — returns data when awaited
// ---------------------------------------------------------------------------

class _FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final PostgrestList data;
  _FakeFilterBuilder([this.data = const []]);

  @override
  PostgrestFilterBuilder<PostgrestList> gt(String column, Object value) => this;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(PostgrestList) onValue, {
    Function? onError,
  }) {
    return Future.value(onValue(data) as S);
  }
}

// ---------------------------------------------------------------------------
// Fake SupabaseQueryBuilder — records last call, returns configurable filter
// ---------------------------------------------------------------------------

// ignore: must_be_immutable
class _FakeSupabaseQueryBuilder extends Fake implements SupabaseQueryBuilder {
  PostgrestFilterBuilder<PostgrestList> Function()? onUpsert;
  PostgrestFilterBuilder<PostgrestList> Function()? onSelect;
  String? lastTable;

  @override
  PostgrestFilterBuilder<PostgrestList> upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    return onUpsert?.call() ?? _FakeFilterBuilder();
  }

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return onSelect?.call() ?? _FakeFilterBuilder();
  }
}

// ---------------------------------------------------------------------------
// Fake SupabaseClient — exposes auth + from
// ---------------------------------------------------------------------------

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth;
  final _FakeSupabaseQueryBuilder queryBuilder;

  _FakeSupabaseClient({required this.auth, required this.queryBuilder});

  @override
  SupabaseQueryBuilder from(String table) {
    queryBuilder.lastTable = table;
    return queryBuilder;
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

final _sampleBook = <String, dynamic>{'id': 'book-1', 'title': 'Cloud Book'};
final _sampleHighlight = <String, dynamic>{
  'id': 1,
  'book_id': 'book-1',
  'selected_text': 'highlight',
};
final _sampleBookmark = <String, dynamic>{
  'id': 1,
  'book_id': 'book-1',
  'label': 'Bookmark',
};

void main() {
  late _MockGoTrueClient mockGoTrue;
  late _FakeSupabaseQueryBuilder fakeQueryBuilder;
  late SupabaseSyncClient syncClient;

  setUp(() {
    mockGoTrue = _MockGoTrueClient();
    fakeQueryBuilder = _FakeSupabaseQueryBuilder();

    syncClient = SupabaseSyncClient(
      _FakeSupabaseClient(auth: mockGoTrue, queryBuilder: fakeQueryBuilder),
    );
  });

  // =========================================================================
  // signInAnonymously
  // =========================================================================

  group('signInAnonymously', () {
    test('returns user id on success', () async {
      final mockUser = _MockUser();
      final mockAuthResponse = _MockAuthResponse();

      when(() => mockUser.id).thenReturn('test-user-123');
      when(() => mockAuthResponse.user).thenReturn(mockUser);
      when(
        () => mockGoTrue.signInAnonymously(),
      ).thenAnswer((_) async => mockAuthResponse);

      expect(await syncClient.signInAnonymously(), 'test-user-123');
    });

    test('throws when user is null', () async {
      final mockAuthResponse = _MockAuthResponse();
      when(() => mockAuthResponse.user).thenReturn(null);
      when(
        () => mockGoTrue.signInAnonymously(),
      ).thenAnswer((_) async => mockAuthResponse);

      await expectLater(syncClient.signInAnonymously(), throwsException);
    });

    test('rethrows on network failure', () async {
      when(
        () => mockGoTrue.signInAnonymously(),
      ).thenThrow(Exception('Network error'));

      await expectLater(syncClient.signInAnonymously(), throwsException);
    });
  });

  // =========================================================================
  // pushBooks
  // =========================================================================

  group('pushBooks', () {
    test('calls upsert with books data', () async {
      fakeQueryBuilder.onUpsert = () => _FakeFilterBuilder();

      await syncClient.pushBooks([_sampleBook]);

      expect(fakeQueryBuilder.lastTable, 'books');
    });

    test('skips upsert on empty list', () async {
      var upsertCalled = false;
      fakeQueryBuilder.onUpsert = () {
        upsertCalled = true;
        return _FakeFilterBuilder();
      };

      await syncClient.pushBooks([]);

      expect(upsertCalled, isFalse);
    });

    test('rethrows on upsert failure', () async {
      fakeQueryBuilder.onUpsert = () => throw Exception('Upsert failed');

      await expectLater(syncClient.pushBooks([_sampleBook]), throwsException);
    });
  });

  // =========================================================================
  // pullBooks
  // =========================================================================

  group('pullBooks', () {
    test('returns pulled books data', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder([_sampleBook]);

      final result = await syncClient.pullBooks(DateTime.now());

      expect(result.length, 1);
      expect(result.first['id'], 'book-1');
      expect(fakeQueryBuilder.lastTable, 'books');
    });

    test('returns empty list when no remote books', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder();

      final result = await syncClient.pullBooks(DateTime.now());
      expect(result, isEmpty);
    });

    test('rethrows on pull failure', () async {
      fakeQueryBuilder.onSelect = () =>
          throw Exception('Supabase connection lost');

      await expectLater(syncClient.pullBooks(DateTime.now()), throwsException);
    });
  });

  // =========================================================================
  // pushHighlights
  // =========================================================================

  group('pushHighlights', () {
    test('calls upsert with highlights data', () async {
      fakeQueryBuilder.onUpsert = () => _FakeFilterBuilder();

      await syncClient.pushHighlights([_sampleHighlight]);

      expect(fakeQueryBuilder.lastTable, 'highlights');
    });

    test('skips upsert on empty list', () async {
      var upsertCalled = false;
      fakeQueryBuilder.onUpsert = () {
        upsertCalled = true;
        return _FakeFilterBuilder();
      };

      await syncClient.pushHighlights([]);
      expect(upsertCalled, isFalse);
    });

    test('rethrows on upsert failure', () async {
      fakeQueryBuilder.onUpsert = () => throw Exception('Upsert failed');

      await expectLater(
        syncClient.pushHighlights([_sampleHighlight]),
        throwsException,
      );
    });
  });

  // =========================================================================
  // pullHighlights
  // =========================================================================

  group('pullHighlights', () {
    test('returns pulled highlights data', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder([_sampleHighlight]);

      final result = await syncClient.pullHighlights(DateTime.now());
      expect(result.length, 1);
      expect(result.first['id'], 1);
      expect(fakeQueryBuilder.lastTable, 'highlights');
    });

    test('returns empty list when no remote highlights', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder();

      final result = await syncClient.pullHighlights(DateTime.now());
      expect(result, isEmpty);
    });

    test('rethrows on pull failure', () async {
      fakeQueryBuilder.onSelect = () =>
          throw Exception('Supabase connection lost');

      await expectLater(
        syncClient.pullHighlights(DateTime.now()),
        throwsException,
      );
    });
  });

  // =========================================================================
  // pushBookmarks
  // =========================================================================

  group('pushBookmarks', () {
    test('calls upsert with bookmarks data', () async {
      fakeQueryBuilder.onUpsert = () => _FakeFilterBuilder();

      await syncClient.pushBookmarks([_sampleBookmark]);

      expect(fakeQueryBuilder.lastTable, 'bookmarks');
    });

    test('skips upsert on empty list', () async {
      var upsertCalled = false;
      fakeQueryBuilder.onUpsert = () {
        upsertCalled = true;
        return _FakeFilterBuilder();
      };

      await syncClient.pushBookmarks([]);
      expect(upsertCalled, isFalse);
    });

    test('rethrows on upsert failure', () async {
      fakeQueryBuilder.onUpsert = () => throw Exception('Upsert failed');

      await expectLater(
        syncClient.pushBookmarks([_sampleBookmark]),
        throwsException,
      );
    });
  });

  // =========================================================================
  // pullBookmarks
  // =========================================================================

  group('pullBookmarks', () {
    test('returns pulled bookmarks data', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder([_sampleBookmark]);

      final result = await syncClient.pullBookmarks(DateTime.now());
      expect(result.length, 1);
      expect(result.first['label'], 'Bookmark');
      expect(fakeQueryBuilder.lastTable, 'bookmarks');
    });

    test('returns empty list when no remote bookmarks', () async {
      fakeQueryBuilder.onSelect = () => _FakeFilterBuilder();

      final result = await syncClient.pullBookmarks(DateTime.now());
      expect(result, isEmpty);
    });

    test('rethrows on pull failure', () async {
      fakeQueryBuilder.onSelect = () =>
          throw Exception('Supabase connection lost');

      await expectLater(
        syncClient.pullBookmarks(DateTime.now()),
        throwsException,
      );
    });
  });
}
