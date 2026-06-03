abstract class CloudSyncClient {
  /// Silently authenticates the current device anonymously on the backend.
  /// Returns the authenticated User ID string.
  Future<String> signInAnonymously();

  /// Pushes a delta list of books to the cloud.
  Future<void> pushBooks(List<Map<String, dynamic>> books);

  /// Pulls a delta list of books modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> pullBooks(DateTime since);

  /// Pushes a delta list of highlights to the cloud.
  Future<void> pushHighlights(List<Map<String, dynamic>> highlights);

  /// Pulls a delta list of highlights modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> pullHighlights(DateTime since);

  /// Pushes a delta list of bookmarks to the cloud.
  Future<void> pushBookmarks(List<Map<String, dynamic>> bookmarks);

  /// Pulls a delta list of bookmarks modified after the [since] timestamp.
  Future<List<Map<String, dynamic>>> pullBookmarks(DateTime since);
}
