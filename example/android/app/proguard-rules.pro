# ProGuard rules for Realbook Reader
# Keep Flutter engine and plugin classes — plugins are loaded via reflection
# by the Flutter plugin registration system; stripping them causes silent
# MethodChannel failures (MissingPluginException).
-keep class app.realbook.reader.MainActivity { *; }
-keep class app.realbook.reader.GeneratedPluginRegistrant { *; }

# Keep RealPageFlipPlugin (haptic engine) — implements MethodCallHandler via
# Flutter plugin API; ProGuard cannot infer this from the app's DEX references.
-keep class com.chapdcha.real_page_flip.** { *; }

# Keep all Flutter plugin classes and method call handlers to prevent silent
# MissingPluginException on any MethodChannel.
-keep class * extends io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * implements io.flutter.embedding.engine.plugins.FlutterPlugin { *; }

# Suppress warnings for libraries not directly referenced at runtime
-dontwarn com.google.android.gms.**
