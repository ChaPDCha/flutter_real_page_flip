import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/cloud_sync_client.dart';

class SupabaseSyncClient implements CloudSyncClient {
  final SupabaseClient _client;

  SupabaseSyncClient(this._client);

  @override
  Future<String> signInAnonymously() async {
    final response = await _client.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw Exception('Supabase anonymous sign-in returned a null user.');
    }
    return user.id;
  }

  @override
  Future<void> pushBooks(List<Map<String, dynamic>> books) async {
    if (books.isEmpty) return;
    await _client.from('books').upsert(books);
  }

  @override
  Future<List<Map<String, dynamic>>> pullBooks(DateTime since) async {
    final response = await _client
        .from('books')
        .select()
        .gt('updated_at', since.toUtc().toIso8601String());
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> pushHighlights(List<Map<String, dynamic>> highlights) async {
    if (highlights.isEmpty) return;
    await _client.from('highlights').upsert(highlights);
  }

  @override
  Future<List<Map<String, dynamic>>> pullHighlights(DateTime since) async {
    final response = await _client
        .from('highlights')
        .select()
        .gt('updated_at', since.toUtc().toIso8601String());
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<void> pushBookmarks(List<Map<String, dynamic>> bookmarks) async {
    if (bookmarks.isEmpty) return;
    await _client.from('bookmarks').upsert(bookmarks);
  }

  @override
  Future<List<Map<String, dynamic>>> pullBookmarks(DateTime since) async {
    final response = await _client
        .from('bookmarks')
        .select()
        .gt('updated_at', since.toUtc().toIso8601String());
    return List<Map<String, dynamic>>.from(response);
  }
}
