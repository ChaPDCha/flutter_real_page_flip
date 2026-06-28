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

  /// Minimum interval between sync cycles. Prevents request storms from
  /// rapid state changes (e.g., batch highlight operations that trigger
  /// individual sync() calls).
  static const _minSyncInterval = Duration(seconds: 10);
  DateTime? _lastSyncCompletedAt;

  /// Cap for the initial sync lookback window. A brand-new user with
  /// last_synced_at = epoch 0 would otherwise pull ALL historic records.
  /// 30 days is more than enough for a first sync — older data is unlikely
  /// to exist for a new anonymous user anyway.
  static const _initialSyncMaxLookback = Duration(days: 30);

  @override
  SyncState build() {
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

    // Rate limiting: reject if called within minSyncInterval of last completion
    if (_lastSyncCompletedAt != null &&
        DateTime.now().difference(_lastSyncCompletedAt!) < _minSyncInterval) {
      return;
    }

    _isSyncing = true;
    final originalState = state;
    state = state.copyWith(status: SyncStatus.authenticating);

    try {
      // 1. Frictionless Anonymous Onboarding Setup
      final userId = await _syncClient.signInAnonymously();

      // Load last sync anchor; cap initial sync lookback to 30 days
      final lastSyncedMs = _prefs.getInt('sync_last_synced_at_ms') ?? 0;
      var lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(
        lastSyncedMs,
        isUtc: true,
      );

      // Never pull data older than _initialSyncMaxLookback from now.
      // This bounds the first-sync query range and avoids full-table scans
      // on the (user_id, updated_at) index.
      final maxLookback = DateTime.now().toUtc().subtract(_initialSyncMaxLookback);
      if (lastSyncedAt.isBefore(maxLookback)) {
        lastSyncedAt = maxLookback;
      }

      final syncStartEpoch = DateTime.now().toUtc();

      // 2. Pull Remote Deltas
      state = state.copyWith(status: SyncStatus.pulling);
      final pullResults = await Future.wait([
        _syncClient.pullBooks(lastSyncedAt),
        _syncClient.pullHighlights(lastSyncedAt),
        _syncClient.pullBookmarks(lastSyncedAt),
      ]);
      final remoteBooks = pullResults[0];
      final remoteHighlights = pullResults[1];
      final remoteBookmarks = pullResults[2];

      await _repository.mergeRemoteBooks(remoteBooks);
      await _repository.mergeRemoteHighlights(remoteHighlights);
      await _repository.mergeRemoteBookmarks(remoteBookmarks);

      // 3. Push Local Deltas
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

      await Future.wait([
        _syncClient.pushBooks(securedBooks),
        _syncClient.pushHighlights(securedHighlights),
        _syncClient.pushBookmarks(securedBookmarks),
      ]);

      // 4. Finalize Sync Vector
      await _prefs.setInt(
        'sync_last_synced_at_ms',
        syncStartEpoch.millisecondsSinceEpoch,
      );
      _lastSyncCompletedAt = DateTime.now();
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
