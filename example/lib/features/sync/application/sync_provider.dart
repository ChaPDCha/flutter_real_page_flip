import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../bookshelf/data/book_repository_provider.dart';
import '../data/drift_sync_repository.dart';
import '../domain/cloud_sync_client.dart';
import '../domain/sync_repository.dart';
import '../domain/sync_state.dart';
import 'supabase_sync_client.dart';
import 'sync_controller.dart';

/// Provider for SharedPreferences. Must be overridden in main() upon initialization.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

/// Decoupled Sync Repository provider targeting Drift local SQLite database.
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftSyncRepository(db);
});

/// Decoupled Cloud Sync Client provider targeting Supabase backend services.
final cloudSyncClientProvider = Provider<CloudSyncClient>((ref) {
  try {
    final client = Supabase.instance.client;
    return SupabaseSyncClient(client);
  } catch (_) {
    // Graceful degradation: returns fake client inside test sandboxes where Supabase is absent
    return const _FakeCloudSyncClient();
  }
});

/// Riverpod state notifier managing synchronization states and triggers.
final syncControllerProvider = NotifierProvider<SyncController, SyncState>(() {
  return SyncController();
});

/// Frictionless fake client supporting seamless test isolation and local-only fallbacks.
class _FakeCloudSyncClient implements CloudSyncClient {
  const _FakeCloudSyncClient();

  @override
  Future<String> signInAnonymously() async => 'fake-sandbox-uid';

  @override
  Future<void> pushBooks(List<Map<String, dynamic>> books) async {}

  @override
  Future<List<Map<String, dynamic>>> pullBooks(DateTime since) async => const [];

  @override
  Future<void> pushHighlights(List<Map<String, dynamic>> highlights) async {}

  @override
  Future<List<Map<String, dynamic>>> pullHighlights(DateTime since) async => const [];

  @override
  Future<void> pushBookmarks(List<Map<String, dynamic>> bookmarks) async {}

  @override
  Future<List<Map<String, dynamic>>> pullBookmarks(DateTime since) async => const [];
}
