import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/firebase/firebase_service.dart';
import '../domain/cloud_sync_client.dart';

class SupabaseSyncClient implements CloudSyncClient {
  final SupabaseClient _client;

  /// Max records per pull page. Keeps response size & memory bounded.
  /// Supabase PostgREST default max is 1000; 500 is a safe balance.
  static const int pullPageSize = 500;

  /// Max records per upsert chunk. Prevents payload size limit breaches
  /// and avoids request timeout on large syncs.
  static const int pushChunkSize = 50;

  SupabaseSyncClient(this._client);

  @override
  Future<String> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw Exception('Supabase anonymous sign-in returned a null user.');
      }
      return user.id;
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase signInAnonymously');
      rethrow;
    }
  }

  @override
  Future<void> pushBooks(List<Map<String, dynamic>> books) async {
    if (books.isEmpty) return;
    try {
      for (int i = 0; i < books.length; i += pushChunkSize) {
        final chunk = books.sublist(i, i + pushChunkSize > books.length ? books.length : i + pushChunkSize);
        await _client.from('books').upsert(chunk);
      }
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushBooks');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullBooks(DateTime since) async {
    try {
      return await _paginatedSelect('books', since);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullBooks');
      rethrow;
    }
  }

  @override
  Future<void> pushHighlights(List<Map<String, dynamic>> highlights) async {
    if (highlights.isEmpty) return;
    try {
      for (int i = 0; i < highlights.length; i += pushChunkSize) {
        final chunk = highlights.sublist(i, i + pushChunkSize > highlights.length ? highlights.length : i + pushChunkSize);
        await _client.from('highlights').upsert(chunk);
      }
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushHighlights');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullHighlights(DateTime since) async {
    try {
      return await _paginatedSelect('highlights', since);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullHighlights');
      rethrow;
    }
  }

  @override
  Future<void> pushBookmarks(List<Map<String, dynamic>> bookmarks) async {
    if (bookmarks.isEmpty) return;
    try {
      for (int i = 0; i < bookmarks.length; i += pushChunkSize) {
        final chunk = bookmarks.sublist(i, i + pushChunkSize > bookmarks.length ? bookmarks.length : i + pushChunkSize);
        await _client.from('bookmarks').upsert(chunk);
      }
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushBookmarks');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullBookmarks(DateTime since) async {
    try {
      return await _paginatedSelect('bookmarks', since);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullBookmarks');
      rethrow;
    }
  }

  /// Pulls all records from [table] with updated_at > [since] using
  /// cursor-based pagination to bound per-request response size.
  Future<List<Map<String, dynamic>>> _paginatedSelect(
    String table,
    DateTime since,
  ) async {
    final allResults = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final response = await _client
          .from(table)
          .select()
          .gt('updated_at', since.toUtc().toIso8601String())
          .order('updated_at')
          .range(from, from + pullPageSize - 1);

      final page = List<Map<String, dynamic>>.from(response);
      allResults.addAll(page);

      if (page.length < pullPageSize) break;
      from += pullPageSize;
    }

    return allResults;
  }
}
