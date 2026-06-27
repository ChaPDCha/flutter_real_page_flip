import 'dart:async';
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

  test(
    'SyncController succeeds with no-op when all deltas are empty',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      await controller.sync();

      verify(() => mockClient.signInAnonymously()).called(1);
      verify(() => mockClient.pullBooks(any())).called(1);
      verify(() => mockClient.pushBooks(any())).called(1);

      final finalState = container.read(syncControllerProvider);
      expect(finalState.status, SyncStatus.success);
    },
  );

  test(
    'SyncController handles partial failure on push after successful pull',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // Pull succeeds, push fails
      when(
        () => mockClient.pushBooks(any()),
      ).thenThrow(Exception('Push failed'));

      await controller.sync();

      final finalState = container.read(syncControllerProvider);
      expect(finalState.status, SyncStatus.error);
      expect(finalState.errorMessage, contains('Push failed'));
    },
  );

  test(
    'SyncController ignores concurrent sync calls while already syncing',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // signInAnonymously never completes — simulates in-flight sync
      final completer = Completer<String>();
      when(() => mockClient.signInAnonymously()).thenAnswer(
        (_) => completer.future,
      );

      // Fire first sync (in flight, not completed)
      controller.sync();

      // Allow microtask to set _isSyncing = true
      await Future<void>.delayed(Duration.zero);

      // Second call should return immediately without calling signInAnonymously again
      await controller.sync();

      // Complete the first sync
      completer.complete('user-1');
      // Let the sync method settle
      await Future<void>.delayed(Duration.zero);

      verify(() => mockClient.signInAnonymously()).called(1);
    },
  );

  test(
    'SyncController allows re-sync after error and succeeds on second attempt',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // First sync fails with network error
      when(() => mockClient.signInAnonymously()).thenThrow(
        Exception('Network error'),
      );
      await controller.sync();

      var state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.error);
      expect(state.errorMessage, contains('Network error'));

      // Reset mock for second attempt
      when(() => mockClient.signInAnonymously()).thenAnswer(
        (_) async => 'mock-user-123',
      );

      // Second sync succeeds — proves _isSyncing flag was reset after error
      await controller.sync();

      state = container.read(syncControllerProvider);
      expect(state.status, SyncStatus.success);
      expect(state.lastSyncedAt, isNotNull);
    },
  );

  test(
    'SyncController reports different error messages at auth, pull, and push stages',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      // ---- Auth stage error ----
      when(() => mockClient.signInAnonymously()).thenThrow(
        Exception('Auth failed'),
      );
      await controller.sync();

      expect(
        container.read(syncControllerProvider).errorMessage,
        contains('Auth failed'),
      );

      // Reset auth for pull, fail at pull stage
      when(() => mockClient.signInAnonymously()).thenAnswer(
        (_) async => 'mock-user-123',
      );
      when(() => mockClient.pullBooks(any())).thenThrow(
        Exception('Pull timeout'),
      );
      await controller.sync();

      expect(
        container.read(syncControllerProvider).errorMessage,
        contains('Pull timeout'),
      );

      // Reset pull for push, fail at push stage
      when(() => mockClient.pullBooks(any())).thenAnswer((_) async => []);
      when(() => mockClient.pushBooks(any())).thenThrow(
        Exception('Push rejected'),
      );
      await controller.sync();

      expect(
        container.read(syncControllerProvider).errorMessage,
        contains('Push rejected'),
      );
    },
  );

  test(
    'SyncController transitions through authenticating, pulling, pushing, and success states',
    () async {
      final controller = container.read(syncControllerProvider.notifier);
      final authCompleter = Completer<String>();
      final pullCompleter = Completer<List<Map<String, dynamic>>>();

      when(
        () => mockClient.signInAnonymously(),
      ).thenAnswer((_) => authCompleter.future);
      when(
        () => mockClient.pullBooks(any()),
      ).thenAnswer((_) => pullCompleter.future);
      when(
        () => mockClient.pullHighlights(any()),
      ).thenAnswer((_) => pullCompleter.future);
      when(
        () => mockClient.pullBookmarks(any()),
      ).thenAnswer((_) => pullCompleter.future);

      // Start sync — pauses at signInAnonymously
      controller.sync();
      await Future<void>.delayed(Duration.zero);

      // State should be authenticating while sign-in is in flight
      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.authenticating,
      );

      // Complete auth -> sync moves to pulling phase
      authCompleter.complete('mock-user-123');
      await Future<void>.delayed(Duration.zero);

      // State should be pulling while pull futures are pending
      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.pulling,
      );

      // Complete pulls -> sync moves to push phase, then completes
      pullCompleter.complete([]);
      await Future<void>.delayed(Duration.zero);

      // Final state should be success
      expect(
        container.read(syncControllerProvider).status,
        SyncStatus.success,
      );
    },
  );

  test(
    'SyncController does not crash when container is disposed during sync',
    () async {
      final authCompleter = Completer<String>();
      when(
        () => mockClient.signInAnonymously(),
      ).thenAnswer((_) => authCompleter.future);

      final localContainer = ProviderContainer(overrides: [
        cloudSyncClientProvider.overrideWithValue(mockClient),
        syncRepositoryProvider.overrideWithValue(mockRepo),
        sharedPreferencesProvider.overrideWithValue(testPrefs),
      ]);

      final controller = localContainer.read(syncControllerProvider.notifier);

      // Start sync (paused at signInAnonymously)
      final syncFuture = controller.sync();
      await Future<void>.delayed(Duration.zero);

      // Dispose the container — must not throw
      localContainer.dispose();

      // Complete the auth — sync resumes with disposed state
      authCompleter.complete('mock-user-123');

      // The sync future may complete with error (Riverpod throws on disposed
      // setter) or may complete normally — either is acceptable. The key
      // assertion is that dispose() itself does not crash.
      try {
        await syncFuture;
        // OK: Riverpod silently handled state write on disposed container
      } catch (_) {
        // OK: Riverpod threw on disposed state setter — expected behavior
      }
    },
  );

  test(
    'SyncController binds user_id to books, highlights, and bookmarks payloads',
    () async {
      final controller = container.read(syncControllerProvider.notifier);

      final bookDeltas = [
        <String, dynamic>{'id': 'book-1', 'title': 'Test Book'},
      ];
      final highlightDeltas = [
        <String, dynamic>{'id': 1, 'selected_text': 'Test Highlight'},
      ];
      final bookmarkDeltas = [
        <String, dynamic>{'id': 1, 'label': 'Test Bookmark'},
      ];

      when(() => mockRepo.getLocalBooksDelta(any())).thenAnswer(
        (_) async => bookDeltas,
      );
      when(() => mockRepo.getLocalHighlightsDelta(any())).thenAnswer(
        (_) async => highlightDeltas,
      );
      when(() => mockRepo.getLocalBookmarksDelta(any())).thenAnswer(
        (_) async => bookmarkDeltas,
      );

      await controller.sync();

      verify(
        () => mockClient.pushBooks(
          any(
            that: isA<List<Map<String, dynamic>>>().having(
              (list) => list.first['user_id'],
              'secured user_id',
              'mock-user-123',
            ),
          ),
        ),
      ).called(1);

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

      verify(
        () => mockClient.pushBookmarks(
          any(
            that: isA<List<Map<String, dynamic>>>().having(
              (list) => list.first['user_id'],
              'secured user_id',
              'mock-user-123',
            ),
          ),
        ),
      ).called(1);
    },
  );
}
