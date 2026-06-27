import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/sync/application/sync_controller.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';
import 'package:real_page_flip_example/features/sync/presentation/sync_status_badge.dart';
import 'package:real_page_flip_example/features/sync/presentation/sync_wrapper.dart';
import 'package:real_page_flip_example/shared/theme/app_theme_controller.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

// ---------------------------------------------------------------------------
// Spy SyncController: counts sync() calls instead of actually syncing
// ---------------------------------------------------------------------------

class SpySyncController extends SyncController {
  int syncCallCount = 0;

  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);

  @override
  Future<void> sync() async {
    syncCallCount++;
    state = const SyncState(status: SyncStatus.success, lastSyncedAt: null);
  }
}

// ---------------------------------------------------------------------------
// Widget builder helpers
// ---------------------------------------------------------------------------

const _childWidget = Text('Wrapped Child Content');

Widget buildWrapper({
  required SpySyncController spyController,
  required SharedPreferences prefs,
  Widget child = _childWidget,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncControllerProvider.overrideWith(() => spyController),
      appThemeControllerProvider.overrideWith(() => AppThemeController()),
    ],
    child: MaterialApp(
      home: Scaffold(body: SyncWrapper(child: child)),
    ),
  );
}

void main() {
  late SpySyncController spyController;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_theme': 'charcoal'});
    prefs = await SharedPreferences.getInstance();
    spyController = SpySyncController();
  });

  group('SyncWrapper', () {
    testWidgets('renders the child widget', (tester) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );
      await tester.pump();

      expect(find.text('Wrapped Child Content'), findsOneWidget);

      // Consume pending timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('contains a SyncStatusBadge overlay', (tester) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );
      await tester.pump();

      expect(find.byType(SyncStatusBadge), findsOneWidget);

      // Consume pending timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('uses correct background color from theme', (tester) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );
      await tester.pump();

      // The SyncWrapper applies the theme background color to its Scaffold
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).last);
      expect(
        scaffold.backgroundColor,
        ReaderThemeData.charcoal.backgroundColor,
      );

      // Consume pending timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('child is wrapped in a Stack with badge overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );
      await tester.pump();

      // The inner Stack (last in tree) is the wrapper's explicit Stack
      expect(find.byType(Stack), findsWidgets);

      expect(find.byType(SafeArea), findsOneWidget);

      // Consume pending timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('defers sync call for 2 seconds after mounting', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );

      // Post-frame callback is scheduled but Future.delayed hasn't fired yet
      await tester.pump();
      expect(spyController.syncCallCount, 0);

      // Advance clock just under 2 seconds
      await tester.pump(const Duration(seconds: 1));
      expect(spyController.syncCallCount, 0);

      // Advance past the 2-second mark
      await tester.pump(const Duration(seconds: 1));
      // After crossing the 2-second threshold, the future should fire
      await tester.pump(const Duration(milliseconds: 50));
      expect(spyController.syncCallCount, 1);

      // Consume badge auto-fade timer created by the sync() call
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('fires periodic sync every 5 minutes', (tester) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );

      // Let the 2-second deferred sync fire first
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(spyController.syncCallCount, 1);

      // Advance 5 minutes - periodic timer should fire
      await tester.pump(const Duration(minutes: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(spyController.syncCallCount, 2);

      // Advance another 5 minutes
      await tester.pump(const Duration(minutes: 5));
      await tester.pump(const Duration(milliseconds: 50));
      expect(spyController.syncCallCount, 3);

      // Consume remaining badge auto-fade timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });

    testWidgets('triggers sync when app resumes from background', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );

      // Let deferred sync fire
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));

      // Simulate app resume
      // ignore: invalid_use_of_protected_member
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // The debounce delays sync by 2 seconds; pump past it
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(spyController.syncCallCount, 2);

      // Consume badge auto-fade timer before test ends
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets('triggers sync when app transitions from inactive to resumed', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );

      // Let deferred sync fire
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));
      final initialCalls = spyController.syncCallCount;

      // inactive -> resumed transition
      // ignore: invalid_use_of_protected_member
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(spyController.syncCallCount, initialCalls); // No sync on inactive

      // ignore: invalid_use_of_protected_member
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // The debounce delays sync by 2 seconds; pump past it
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(spyController.syncCallCount, initialCalls + 1); // Sync on resume

      // Consume badge auto-fade timer before test ends
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    });

    testWidgets(
      'does not trigger sync on lifecycle states other than resumed',
      (tester) async {
        await tester.pumpWidget(
          buildWrapper(spyController: spyController, prefs: prefs),
        );

        // Let deferred sync fire
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 50));
        final initialCalls = spyController.syncCallCount;

        // Lifecycle changes that should NOT trigger sync
        // ignore: invalid_use_of_protected_member
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        expect(
          spyController.syncCallCount,
          initialCalls,
          reason: 'paused should not trigger sync',
        );

        // ignore: invalid_use_of_protected_member
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(
          spyController.syncCallCount,
          initialCalls,
          reason: 'inactive should not trigger sync',
        );

        // ignore: invalid_use_of_protected_member
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.detached,
        );
        await tester.pump();
        expect(
          spyController.syncCallCount,
          initialCalls,
          reason: 'detached should not trigger sync',
        );

        // Periodic 5-min timer is still active; advance past initial tick to
        // avoid "pending timer" assertion at test end.
        await tester.pump(const Duration(minutes: 5));
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets('cancels periodic timer and lifecycle observer on dispose', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWrapper(spyController: spyController, prefs: prefs),
      );

      // Let deferred sync fire
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(spyController.syncCallCount, 1);

      // Remove the widget from the tree by replacing with an empty scaffold
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            syncControllerProvider.overrideWith(() => spyController),
            appThemeControllerProvider.overrideWith(() => AppThemeController()),
          ],
          child: const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        ),
      );
      await tester.pump();

      // Advance clock - the destroyed wrapper's timer should not fire
      await tester.pump(const Duration(minutes: 5));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        spyController.syncCallCount,
        1,
        reason: 'timer should be cancelled on dispose',
      );
    });

    testWidgets('renders custom child widget', (tester) async {
      const customChild = Text('Custom Child');
      await tester.pumpWidget(
        buildWrapper(
          spyController: spyController,
          prefs: prefs,
          child: customChild,
        ),
      );
      await tester.pump();

      expect(find.text('Custom Child'), findsOneWidget);
      expect(find.text('Wrapped Child Content'), findsNothing);

      // Consume pending timers before test ends
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    });
  });
}
