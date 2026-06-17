import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'features/bookshelf/presentation/bookshelf_screen.dart';
import 'features/sync/application/sync_provider.dart';
import 'features/sync/presentation/sync_wrapper.dart';
import 'shared/theme/app_theme_controller.dart';
import 'shared/theme/reader_theme.dart';
import 'shared/firebase/firebase_options.dart';
import 'shared/firebase/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (Crashlytics, Analytics, Remote Config)
  // 싱글톤 초기화가 한 번이라도 성공하면 이후 getter는 예외를 던지지 않는다.
  // 실패 시 모든 FirebaseService 호출이 자동 no-op 처리된다.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Crashlytics 전역 에러 핸들러 — Flutter 프레임워크 에러
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Crashlytics 네이티브 영역 에러 (PlatformDispatcher)
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase 미지원 환경(에뮬레이터, 테스트)에서 조용히 실패.
    // FirebaseService의 lazy getter가 null을 반환하며 모든 호출이 no-op 처리된다.
  }

  // Remote Config 초기화 (비차단 — 기본값 사용 후 백그라운드 업데이트)
  unawaited(FirebaseService.initRemoteConfig());

  // AdMob 초기화 (비차단 — UI 첫 프레임 지연 방지)
  unawaited(MobileAds.instance.initialize());

  final prefs = await SharedPreferences.getInstance();

  // Supabase 초기화 (기존 코드 유지)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
    } catch (_) {
      // Gracefully degrades to local-only SQLite mode if Supabase fails
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

    final materialTheme = themeData.toMaterialTheme();

    return ShadApp(
      title: 'Realbook Reader',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: shadTheme,
      darkTheme: shadTheme,
      themeMode: themeData.isDark ? ThemeMode.dark : ThemeMode.light,
      materialThemeBuilder: (context, theme) => materialTheme,
      home: const SyncWrapper(
        child: BookshelfScreen(),
      ),
    );
  }
}
