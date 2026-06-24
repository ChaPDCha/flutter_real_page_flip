import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cloud_sync_client.dart';
import '../domain/sync_repository.dart';
import '../domain/sync_state.dart';
import 'sync_provider.dart';

class SyncController extends Notifier<SyncState> {
  late final CloudSyncClient _syncClient;
  late final SyncRepository _repository;
  late final SharedPreferences _prefs;
  bool _isSyncing = false;

  @override
  SyncState build() {
    // Declarative Riverpod dependency injection
    _syncClient = ref.watch(cloudSyncClientProvider);
    _repository = ref.watch(syncRepositoryProvider);
    _prefs = ref.watch(sharedPreferencesProvider);

    final lastSyncedMs = _prefs.getInt('sync_last_synced_at_ms') ?? 0;
    return SyncState(
      status: SyncStatus.idle,
      lastSyncedAt: lastSyncedMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncedMs, isUtc: true)
          : null,
    );
  }

  /// Silent anonymous onboarding and bi-directional delta synchronization.
  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    final originalState = state;
    state = state.copyWith(status: SyncStatus.authenticating);

    try {
      // 1. Frictionless Anonymous Onboarding Setup
      final userId = await _syncClient.signInAnonymously();

      // Load last sync anchor
      final lastSyncedMs = _prefs.getInt('sync_last_synced_at_ms') ?? 0;
      final lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(
        lastSyncedMs,
        isUtc: true,
      );
      final syncStartEpoch = DateTime.now().toUtc();

      // 2. Pull Remote Deltas
      state = state.copyWith(status: SyncStatus.pulling);
      final remoteBooks = await _syncClient.pullBooks(lastSyncedAt);
      final remoteHighlights = await _syncClient.pullHighlights(lastSyncedAt);
      final remoteBookmarks = await _syncClient.pullBookmarks(lastSyncedAt);

      await _repository.mergeRemoteBooks(remoteBooks);
      await _repository.mergeRemoteHighlights(remoteHighlights);
      await _repository.mergeRemoteBookmarks(remoteBookmarks);

      // 3. Push Local Deltas with secured user_id attributes (RLS requirement)
      state = state.copyWith(status: SyncStatus.pushing);
      final localBooks = await _repository.getLocalBooksDelta(lastSyncedAt);
      final localHighlights = await _repository.getLocalHighlightsDelta(
        lastSyncedAt,
      );
      final localBookmarks = await _repository.getLocalBookmarksDelta(
        lastSyncedAt,
      );

      final securedBooks = _bindUserId(localBooks, userId);
      final securedHighlights = _bindUserId(localHighlights, userId);
      final securedBookmarks = _bindUserId(localBookmarks, userId);

      await _syncClient.pushBooks(securedBooks);
      await _syncClient.pushHighlights(securedHighlights);
      await _syncClient.pushBookmarks(securedBookmarks);

      // 4. Finalize Sync Vector
      await _prefs.setInt(
        'sync_last_synced_at_ms',
        syncStartEpoch.millisecondsSinceEpoch,
      );
      state = SyncState(
        status: SyncStatus.success,
        lastSyncedAt: syncStartEpoch,
      );
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: e.toString(),
        lastSyncedAt: originalState.lastSyncedAt,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Dynamically binds current authenticating userId to out-going REST payloads.
  List<Map<String, dynamic>> _bindUserId(
    List<Map<String, dynamic>> payloads,
    String userId,
  ) {
    return payloads.map((payload) {
      return Map<String, dynamic>.from(payload)
        ..putIfAbsent('user_id', () => userId);
    }).toList();
  }
}
