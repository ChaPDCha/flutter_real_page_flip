/// Registration hook for Windows, which has no native code.
///
/// The engine is pure Dart on desktop, so `pubspec.yaml` declares Windows as a
/// Dart-only plugin platform (`dartPluginClass`). Flutter's generated plugin
/// registrant calls [registerWith] at startup; it intentionally does nothing.
///
/// Haptic calls have no native counterpart here and fall back to Flutter's
/// built-in `HapticFeedback`. The default page-turn sound is not available on
/// desktop: pass a `PageFlipSoundPlayer`.
// ignore: avoid_classes_with_only_static_members
class RealPageFlipWindows {
  RealPageFlipWindows._();

  /// Called by Flutter's generated plugin registrant; intentionally empty.
  static void registerWith() {}
}
