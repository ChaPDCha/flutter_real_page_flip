import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:real_page_flip_example/features/bookshelf/presentation/widgets/bookshelf_settings_panel.dart';
import 'package:real_page_flip_example/features/sync/application/sync_controller.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';

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
Future<_TestSyncController> openModal(
  WidgetTester tester,
  SyncState syncState,
) async {
  final controller = _TestSyncController(syncState);

  await tester.pumpWidget(
    ProviderScope(
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
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();

  return controller;
}

// ---------------------------------------------------------------------------
// Expected status text per SyncStatus
// ---------------------------------------------------------------------------

const _statusTexts = {
  SyncStatus.idle: '대기 중',
  SyncStatus.authenticating: '인증 확인 중...',
  SyncStatus.pulling: '서재 동기화 가져오는 중...',
  SyncStatus.pushing: '서재 상태 저장 중...',
  SyncStatus.success: '동기화 완료',
  SyncStatus.error: '동기화 중 오류 발생',
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('BookshelfSettingsPanel', () {
    testWidgets('opens modal with correct title', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('서재 설정'), findsOneWidget);
    });

    for (final status in SyncStatus.values) {
      testWidgets('shows correct status text for $status', (tester) async {
        final text = _statusTexts[status]!;
        await openModal(tester, SyncState(status: status));

        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('sync button is enabled when idle', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.idle),
      );

      await tester.tap(find.text('지금 동기화'));
      expect(controller.syncCallCount, 1);
    });

    for (final status in [
      SyncStatus.authenticating,
      SyncStatus.pulling,
      SyncStatus.pushing,
    ]) {
      testWidgets('sync button is disabled during $status', (tester) async {
        final controller = await openModal(tester, SyncState(status: status));

        await tester.tap(find.text('지금 동기화'));
        expect(controller.syncCallCount, 0);
      });
    }

    testWidgets('sync button is enabled after success', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.success),
      );

      await tester.tap(find.text('지금 동기화'));
      expect(controller.syncCallCount, 1);
    });

    testWidgets('sync button is enabled after error', (tester) async {
      final controller = await openModal(
        tester,
        const SyncState(status: SyncStatus.error, errorMessage: 'err'),
      );

      await tester.tap(find.text('지금 동기화'));
      expect(controller.syncCallCount, 1);
    });

    testWidgets('shows app version and engine info', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('v1.5.2'), findsOneWidget);
      expect(find.text('3D PageFlip Core v2.5.0'), findsOneWidget);
    });

    testWidgets('shows settings complete button', (tester) async {
      await openModal(tester, const SyncState(status: SyncStatus.idle));

      expect(find.text('설정 완료'), findsOneWidget);
    });
  });
}
