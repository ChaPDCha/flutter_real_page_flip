import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/sync/application/sync_controller.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/features/sync/domain/sync_state.dart';
import 'package:real_page_flip_example/features/sync/presentation/sync_status_badge.dart';
import 'package:real_page_flip_example/shared/theme/app_theme_controller.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

// ---------------------------------------------------------------------------
// Test Notifier: controllable sync state
// ---------------------------------------------------------------------------

class SyncStateController extends SyncController {
  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);

  void setStateTo(SyncStatus status, {String? errorMessage}) {
    state = SyncState(status: status, errorMessage: errorMessage);
  }

  @override
  Future<void> sync() async {
    // Prevent accidental access to uninitialized late fields
    state = const SyncState(status: SyncStatus.success);
  }
}

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget buildBadge({
  required SyncStateController syncController,
  required SharedPreferences prefs,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      syncControllerProvider.overrideWith(() => syncController),
      appThemeControllerProvider.overrideWith(() => AppThemeController()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SyncStatusBadge(),
      ),
    ),
  );
}

void main() {
  late SyncStateController syncController;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'app_theme': 'charcoal'});
    prefs = await SharedPreferences.getInstance();
    syncController = SyncStateController();
  });

  group('SyncStatusBadge', () {
    testWidgets('renders without error when idle', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      expect(find.byType(SyncStatusBadge), findsOneWidget);
    });

    testWidgets('shows syncing dot when status is authenticating', (
      tester,
    ) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.authenticating);
      await tester.pump();

      // The dot container (8x8 circle) should now be rendered
      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.charcoal.accentColor);
    });

    testWidgets('shows syncing dot when status is pulling', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.pulling);
      await tester.pump();

      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.charcoal.accentColor);
    });

    testWidgets('shows syncing dot when status is pushing', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.pushing);
      await tester.pump();

      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.charcoal.accentColor);
    });

    testWidgets('shows green dot on success state', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.success);
      await tester.pump();

      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.successColor);

      // Consume the 2-second auto-fade timer from _updateBadge
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('shows red dot on error state', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.error,
          errorMessage: 'Connection failed');
      await tester.pump();

      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.errorColor);

      // Consume the 3-second auto-fade timer from _updateBadge
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });

    testWidgets('dot is not visible when idle', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      // In idle state, the dot Container should not appear
      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsNothing);
    });

    testWidgets('hides dot after 2 seconds in success state', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.success);
      await tester.pump();

      // Dot should be visible
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsOneWidget,
      );

      // Advance clock past the 2-second auto-fade
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 50));

      // Dot should now be hidden
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNothing,
      );
    });

    testWidgets('hides dot after 3 seconds in error state', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.error,
          errorMessage: 'Temporary error');
      await tester.pump();

      // Dot should be visible
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsOneWidget,
      );

      // Advance clock past the 3-second auto-fade
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 50));

      // Dot should now be hidden
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
        findsNothing,
      );
    });

    testWidgets('does not auto-hide if status changed before fade', (
      tester,
    ) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      // Set to success, then immediately to syncing before fade completes
      syncController.setStateTo(SyncStatus.success);
      await tester.pump();

      syncController.setStateTo(SyncStatus.pulling);
      await tester.pump(const Duration(seconds: 2));

      // After 2 seconds, the auto-fade would have fired, but because status
      // is now pulling (not success), the fade should NOT have hidden the dot
      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);
    });

    testWidgets('transitions from error to success state', (tester) async {
      await tester.pumpWidget(buildBadge(
        syncController: syncController,
        prefs: prefs,
      ));
      await tester.pump();

      syncController.setStateTo(SyncStatus.error,
          errorMessage: 'First error');
      await tester.pump();

      syncController.setStateTo(SyncStatus.success);
      await tester.pump();

      // Dot should now show success green color
      final containers = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );
      expect(containers, findsOneWidget);

      final container = tester.widget<Container>(containers);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, ReaderThemeData.successColor);

      // Consume pending auto-fade timers from _updateBadge (3s from error, 2s from success)
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });
  });
}
