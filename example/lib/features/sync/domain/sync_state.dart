enum SyncStatus { idle, authenticating, pulling, pushing, success, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  const SyncState({required this.status, this.errorMessage, this.lastSyncedAt});

  factory SyncState.initial() {
    return const SyncState(status: SyncStatus.idle);
  }

  SyncState copyWith({
    SyncStatus? status,
    String? errorMessage,
    DateTime? lastSyncedAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  String toString() =>
      'SyncState(status: $status, errorMessage: $errorMessage, lastSyncedAt: $lastSyncedAt)';
}
