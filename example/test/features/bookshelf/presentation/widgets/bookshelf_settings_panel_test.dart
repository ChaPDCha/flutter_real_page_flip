import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:real_page_flip_example/features/bookshelf/presentation/widgets/bookshelf_settings_panel.dart';
import 'package:real_page_flip_example/features/sync/application/sync_controller.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';
import 'package:real_page_flip_example/l10n/translations.g.dart';

// ---------------------------------------------------------------------------
// Test SyncController — returns a fixed state and records sync() calls
// ---------------------------------------------------------------------------

class _TestSyncController extends SyncController {
  final SyncState _state;
  int syncCallCount = 0;

  _TestSyncController(this._state);

  @override
  SyncState build() => _state;

  @override
  Future<void> sync() async {
    syncCallCount++;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Opens the modal and returns the test controller for assertions.
// ignore: library_private_types_in_public_api
Future<_TestSyncController> openModal(
  WidgetTester tester,
  SyncState syncState,
) async {
  final controller = _TestSyncController(syncState);

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          syncControllerProvider.overrideWith(() => controller),
        ],
        child: ShadTheme(
          data: ShadThemeData(),
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => ElevatedButton(
                  onPressed: () => BookshelfSettingsPanel.show(
                    context: context,
                    ref: ref,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return controller;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BookshelfSettingsPanel', () {
    testWidgets('opens modal with correct title', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('Shelf Settings'), findsOneWidget);
    });

    testWidgets('shows correct status text for idle', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));
      expect(find.text('Waiting'), findsOneWidget);
    });

    testWidgets('shows correct status text for authenticating', (tester) async {
      await openModal(
        tester,
        const SyncState(status: SyncStatus.authenticating),
      );
      expect(find.text('Verifying...'), findsOneWidget);
    });

    testWidgets('shows correct status text for pulling', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.pulling));
      expect(find.text('Syncing...'), findsOneWidget);
    });

    testWidgets('shows correct status text for pushing', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.pushing));
      expect(find.text('Syncing...'), findsOneWidget);
    });

    testWidgets('shows correct status text for success', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.success));
      expect(find.text('Sync Complete'), findsOneWidget);
    });

    testWidgets('shows correct status text for error', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.error));
      expect(find.text('Sync Error'), findsOneWidget);
    });

    testWidgets('sync button is enabled when idle', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.idle),
      );

      await tester.tap(find.text('Sync Now'));
      expect(controller.syncCallCount, 1);
    });

    for (final status in [
      SyncStatus.authenticating,
      SyncStatus.pulling,
      SyncStatus.pushing,
    ]) {
      testWidgets('sync button is disabled during $status', (tester) async {
        final controller = await openModal(tester, SyncState(status: status));

        await tester.tap(find.text('Sync Now'));
        expect(controller.syncCallCount, 0);
      });
    }

    testWidgets('sync button is enabled after success', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.success),
      );

      await tester.tap(find.text('Sync Now'));
      expect(controller.syncCallCount, 1);
    });

    testWidgets('sync button is enabled after error', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.error, errorMessage: 'err'),
      );

      await tester.tap(find.text('Sync Now'));
      expect(controller.syncCallCount, 1);
    });

    testWidgets('shows app version and engine info', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('v1.7.2'), findsOneWidget);
      expect(find.text('3D PageFlip Core v2.5.0'), findsOneWidget);
    });

    testWidgets('shows settings complete button', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('Done'), findsOneWidget);
    });
  });
}
