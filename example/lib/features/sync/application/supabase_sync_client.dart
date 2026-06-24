import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/firebase/firebase_service.dart';
import '../domain/cloud_sync_client.dart';

class SupabaseSyncClient implements CloudSyncClient {
  final SupabaseClient _client;

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
      await _client.from('books').upsert(books);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushBooks');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullBooks(DateTime since) async {
    try {
      final response = await _client
          .from('books')
          .select()
          .gt('updated_at', since.toUtc().toIso8601String());
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullBooks');
      rethrow;
    }
  }

  @override
  Future<void> pushHighlights(List<Map<String, dynamic>> highlights) async {
    if (highlights.isEmpty) return;
    try {
      await _client.from('highlights').upsert(highlights);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushHighlights');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullHighlights(DateTime since) async {
    try {
      final response = await _client
          .from('highlights')
          .select()
          .gt('updated_at', since.toUtc().toIso8601String());
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullHighlights');
      rethrow;
    }
  }

  @override
  Future<void> pushBookmarks(List<Map<String, dynamic>> bookmarks) async {
    if (bookmarks.isEmpty) return;
    try {
      await _client.from('bookmarks').upsert(bookmarks);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pushBookmarks');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> pullBookmarks(DateTime since) async {
    try {
      final response = await _client
          .from('bookmarks')
          .select()
          .gt('updated_at', since.toUtc().toIso8601String());
      return List<Map<String, dynamic>>.from(response);
    } catch (e, st) {
      FirebaseService.recordError(e, st, reason: 'Supabase pullBookmarks');
      rethrow;
    }
  }
}
