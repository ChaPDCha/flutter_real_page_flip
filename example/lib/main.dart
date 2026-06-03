import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'features/bookshelf/presentation/bookshelf_screen.dart';
import 'features/sync/application/sync_provider.dart';
import 'features/sync/presentation/sync_wrapper.dart';
import 'shared/theme/app_theme_controller.dart';
import 'shared/theme/reader_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // Dynamic build-time environment variable injection using native --dart-define-from-file
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } catch (_) {
      // Gracefully degrades to local-only SQLite mode if Supabase fails initializing
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeType = ref.watch(appThemeControllerProvider);
    final themeData = ReaderThemeData.get(themeType);
    final shadTheme = themeData.toShadTheme();

    return ShadApp(
      title: 'Realbook Reader',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: shadTheme,
      darkTheme: shadTheme,
      themeMode: themeData.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const SyncWrapper(
        child: BookshelfScreen(),
      ),
    );
  }
}
