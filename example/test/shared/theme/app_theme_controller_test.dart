import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:real_page_flip_example/features/sync/application/sync_provider.dart';
import 'package:real_page_flip_example/shared/theme/app_theme_controller.dart';
import 'package:real_page_flip_example/shared/theme/reader_theme.dart';

void main() {
  group('AppThemeController Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to charcoal when no preference is saved', () {
      final container = createContainer();
      expect(
        container.read(appThemeControllerProvider),
        equals(ReaderThemeType.charcoal),
      );
    });

    test('loads saved theme from SharedPreferences', () async {
      await prefs.setString('app_theme', 'cream');

      final container = createContainer();
      expect(
        container.read(appThemeControllerProvider),
        equals(ReaderThemeType.cream),
      );
    });

    test('setTheme persists selection to SharedPreferences', () async {
      final container = createContainer();

      await container
          .read(appThemeControllerProvider.notifier)
          .setTheme(ReaderThemeType.cream);
      expect(
        container.read(appThemeControllerProvider),
        equals(ReaderThemeType.cream),
      );
      expect(prefs.getString('app_theme'), equals('cream'));

      await container
          .read(appThemeControllerProvider.notifier)
          .setTheme(ReaderThemeType.charcoal);
      expect(
        container.read(appThemeControllerProvider),
        equals(ReaderThemeType.charcoal),
      );
      expect(prefs.getString('app_theme'), equals('charcoal'));
    });

    test('migrates legacy reader_settings sepia theme to cream', () async {
      await prefs.setString(
        'reader_settings',
        '{"themeType":"sepia","fontSize":16.0,"lineHeight":1.6,"enableHaptics":true,"enableSound":true}',
      );

      final container = createContainer();
      expect(
        container.read(appThemeControllerProvider),
        equals(ReaderThemeType.cream),
      );
    });
  });
}
