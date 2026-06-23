import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/domain/cloud_sync_client.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_repository.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';

class MockCloudSyncClient extends Mock implements CloudSyncClient {}

class MockSyncRepository extends Mock implements SyncRepository {}

void main() {
  late MockCloudSyncClient mockClient;
  late MockSyncRepository mockRepo;
  late SharedPreferences testPrefs;
  late ProviderContainer container;

  setUp(() async {
    mockClient = MockCloudSyncClient();
    mockRepo = MockSyncRepository();

    // Set up real SharedPreferences in memory mock context
    SharedPreferences.setMockInitialValues({'sync_last_synced_at_ms': 1000});
    testPrefs = await SharedPreferences.getInstance();

    // Wire dependency overrides
    container = ProviderContainer(
      overrides: [
        cloudSyncClientProvider.overrideWithValue(mockClient),
        syncRepositoryProvider.overrideWithValue(mockRepo),
        sharedPreferencesProvider.overrideWithValue(testPrefs),
      ],
    );

    // Register stub defaults
    when(
      () => mockClient.signInAnonymously(),
    ).thenAnswer((_) async => 'mock-user-123');

    // Stub Pull Deltas
    when(() => mockClient.pullBooks(any())).thenAnswer((_) async => []);
    when(() => mockClient.pullHighlights(any())).thenAnswer((_) async => []);
    when(() => mockClient.pullBookmarks(any())).thenAnswer((_) async => []);

    // Stub Local Repository merges
    when(() => mockRepo.mergeRemoteBooks(any())).thenAnswer((_) async {});
    when(() => mockRepo.mergeRemoteHighlights(any())).thenAnswer((_) async {});
    when(() => mockRepo.mergeRemoteBookmarks(any())).thenAnswer((_) async {});

    // Stub Local Deltas
    when(() => mockRepo.getLocalBooksDelta(any())).thenAnswer((_) async => []);
    when(
      () => mockRepo.getLocalHighlightsDelta(any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockRepo.getLocalBookmarksDelta(any()),
    ).thenAnswer((_) async => []);

    // Stub Push Deltas
    when(() => mockClient.pushBooks(any())).thenAnswer((_) async {});
    when(() => mockClient.pushHighlights(any())).thenAnswer((_) async {});
    when(() => mockClient.pushBookmarks(any())).thenAnswer((_) async {});
  });

  tearDown(() {
    container.dispose();
  });

  // Ensure parameter fallback matching
  setUpAll(() {
    registerFallbackValue(DateTime.now());
  });

  test(
    'SyncController initializes in idle state with correct timestamp anchor',
    () {
      final state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.idle);
      expect(state.lastSyncedAt?.millisecondsSinceEpoch, 1000);
    },
  );

  test(
    'SyncController silent anonymous sign-in and bidirectional sync flow succeeds',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // Prepare delta payload mock assets
      final mockBookDelta = [
        {'id': 'book-1', 'title': 'Cloud Title'},
      ];
      final mockHighlightDelta = [
        {
          'id': 2,
          'book_id': 'book-1',
          'selected_text': 'Warm golden highlight',
        },
      ];

      when(
        () => mockClient.pullBooks(any()),
      ).thenAnswer((_) async => mockBookDelta);
      when(
        () => mockRepo.getLocalHighlightsDelta(any()),
      ).thenAnswer((_) async => mockHighlightDelta);

      // Execute bi-directional sync loop
      await controller.sync();

      // Verify authentication and remote pulls
      verify(() => mockClient.signInAnonymously()).called(1);
      verify(() => mockClient.pullBooks(any())).called(1);
      verify(() => mockRepo.mergeRemoteBooks(mockBookDelta)).called(1);

      // Verify user ID mapping and local pushing
      verify(
        () => mockClient.pushHighlights(
          any(
            that: isA<List<Map<String, dynamic>>>().having(
              (list) => list.first['user_id'],
              'secured user_id',
              'mock-user-123',
            ),
          ),
        ),
      ).called(1);

      // Assert final sync success vectors
      final finalState = container.read(syncControllerProvider);
      expect(finalState.status, SyncStatus.success);
      expect(finalState.lastSyncedAt, isNotNull);

      // Verify sync anchor persists to storage
      expect(testPrefs.getInt('sync_last_synced_at_ms'), isNotNull);
      expect(testPrefs.getInt('sync_last_synced_at_ms'), isNot(1000));
    },
  );

  test(
    'SyncController sets error state and handles exception gracefully on network failure',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // Force a network failure exception
      when(
        () => mockClient.signInAnonymously(),
      ).thenThrow(Exception('Supabase connection lost'));

      // Execute sync and verify it handles exception without crashing/rethrowing
      await controller.sync();

      final finalState = container.read(syncControllerProvider);
      expect(finalState.status, SyncStatus.error);
      expect(finalState.errorMessage, contains('Supabase connection lost'));
      expect(
        finalState.lastSyncedAt?.millisecondsSinceEpoch,
        1000,
      ); // Preserves previous anchor
    },
  );
}
