abstract class SyncRepository {
  /// Fetches local books modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> getLocalBooksDelta(DateTime since);

  /// Fetches local highlights modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> getLocalHighlightsDelta(DateTime since);

  /// Fetches local bookmarks modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> getLocalBookmarksDelta(DateTime since);

  /// Merges remote book deltas using LWW conflict resolution.
  Future<void> mergeRemoteBooks(List<Map<String, dynamic>> books);

  /// Merges remote highlight deltas using LWW conflict resolution.
  Future<void> mergeRemoteHighlights(List<Map<String, dynamic>> highlights);

  /// Merges remote bookmark deltas using LWW conflict resolution.
  Future<void> mergeRemoteBookmarks(List<Map<String, dynamic>> bookmarks);
}
