import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme_dialogs.dart';

/// Helper that pumps a MaterialApp wrapping a button whose onPressed
/// triggers one of the themed dialog functions.
Future<void> pumpDialogLauncher({
  required WidgetTester tester,
  required Future<void> Function(BuildContext context) onPressed,
  Locale locale = const Locale('en', 'US'),
  List<Locale> supportedLocales = const [Locale('en', 'US')],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            await onPressed(context);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('showThemedDialog', () {
    testWidgets('shows dialog with builder content', (tester) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Dialog Content'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsOneWidget);
    });

    testWidgets('applies charcoal theme to dialog', (tester) async {
      Color? surfaceColor;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (dialogContext) {
            surfaceColor = Theme.of(dialogContext).colorScheme.surface;
            return const Text('Theme Check');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(surfaceColor, isNotNull);
      expect(surfaceColor, ReaderThemeData.charcoal.panelColor);
    });

    testWidgets('applies cream theme to dialog', (tester) async {
      Color? scaffoldBackground;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.cream,
          builder: (dialogContext) {
            scaffoldBackground = Theme.of(
              dialogContext,
            ).scaffoldBackgroundColor;
            return const Text('Cream Theme');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(scaffoldBackground, ReaderThemeData.cream.backgroundColor);
    });

    testWidgets('color scheme is correctly applied', (tester) async {
      Color? onSurfaceColor;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (dialogContext) {
            onSurfaceColor = Theme.of(dialogContext).colorScheme.onSurface;
            return const Text('Colors');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(onSurfaceColor, ReaderThemeData.charcoal.textColor);
    });

    testWidgets('dialog can be dismissed by tapping barrier', (tester) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Dismissible'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Dismissible'), findsOneWidget);

      // Tap outside the dialog on the barrier
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Dismissible'), findsNothing);
    });

    testWidgets('barrierDismissible false prevents dismissal via barrier', (
      tester,
    ) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Not Dismissible'),
          barrierDismissible: false,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Not Dismissible'), findsOneWidget);

      // Try tapping outside
      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Not Dismissible'), findsOneWidget);
    });

    testWidgets('button inside dialog is tappable', (tester) async {
      var wasTapped = false;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (dialogContext) => ElevatedButton(
            onPressed: () {
              wasTapped = true;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Inside'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Inside'), findsOneWidget);

      await tester.tap(find.text('Inside'));
      await tester.pumpAndSettle();
      expect(wasTapped, isTrue);
      expect(find.text('Inside'), findsNothing);
    });
  });

  group('showThemedAdaptiveDialog', () {
    testWidgets('shows dialog with builder content', (tester) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedAdaptiveDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Adaptive Content'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Adaptive Content'), findsOneWidget);
    });

    testWidgets('applies charcoal theme to adaptive dialog', (tester) async {
      Color? surfaceColor;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedAdaptiveDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (dialogContext) {
            surfaceColor = Theme.of(dialogContext).colorScheme.surface;
            return const Text('Adaptive Theme');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(surfaceColor, ReaderThemeData.charcoal.panelColor);
    });

    testWidgets('applies cream theme to adaptive dialog', (tester) async {
      Color? onSurface;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedAdaptiveDialog(
          context: context,
          theme: ReaderThemeData.cream,
          builder: (dialogContext) {
            onSurface = Theme.of(dialogContext).colorScheme.onSurface;
            return const Text('Cream Adaptive');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(onSurface, ReaderThemeData.cream.textColor);
    });

    testWidgets('adaptive dialog can be dismissed by barrier', (tester) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedAdaptiveDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Adaptive Dismiss'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Adaptive Dismiss'), findsOneWidget);

      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Adaptive Dismiss'), findsNothing);
    });

    testWidgets('adaptive dialog barrierDismissible false prevents dismiss', (
      tester,
    ) async {
      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedAdaptiveDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (_) => const Text('Adaptive Stays'),
          barrierDismissible: false,
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Adaptive Stays'), findsOneWidget);

      await tester.tapAt(const Offset(0, 0));
      await tester.pumpAndSettle();
      expect(find.text('Adaptive Stays'), findsOneWidget);
    });
  });

  group('theme wrapping accuracy', () {
    testWidgets('text color matches theme inside dialog', (tester) async {
      Color? bodyColor;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.charcoal,
          builder: (dialogContext) {
            bodyColor = Theme.of(dialogContext).textTheme.bodyMedium?.color;
            return const Text('Color Check');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(bodyColor, ReaderThemeData.charcoal.textColor);
    });

    testWidgets('brightness is always dark', (tester) async {
      Brightness? brightness;

      await pumpDialogLauncher(
        tester: tester,
        onPressed: (context) => showThemedDialog(
          context: context,
          theme: ReaderThemeData.cream,
          builder: (dialogContext) {
            brightness = Theme.of(dialogContext).brightness;
            return const Text('Brightness');
          },
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Both themes use dark brightness
      expect(brightness, Brightness.dark);
    });
  });
}
