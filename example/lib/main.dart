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
import 'package:sentry_flutter/sentry_flutter.dart';
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
  } catch (_) {
    // Firebase 미지원 환경(에뮬레이터, 테스트)에서 조용히 실패.
    // FirebaseService의 lazy getter가 null을 반환하며 모든 호출이 no-op 처리된다.
  }

  // Sentry 초기화 (DSN이 설정된 경우에만)
  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    try {
      await SentryFlutter.init(
        (options) => options.dsn = sentryDsn,
      );
    } catch (_) {
      // Sentry 초기화 실패 시 조용히 무시. 다른 에러 리포팅에 영향 없음.
    }
  }

  // 이중 에러 리포팅: Flutter 프레임워크 에러 → Crashlytics + Sentry
  FlutterError.onError = (details) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  // 이중 에러 리포팅: 네이티브 영역 에러 → Crashlytics + Sentry
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

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
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
      home: const SyncWrapper(child: BookshelfScreen()),
    );
  }
}
