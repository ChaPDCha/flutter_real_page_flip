/// No-op web platform stub.
///
/// All haptic calls throw MissingPluginException and fall back to Flutter's
/// built-in HapticFeedback API (light/medium/heavy impact).
// ignore: avoid_classes_with_only_static_members
abstract final class RealPageFlipWeb {
  /// Required by Flutter's generated web plugin registrant.
  ///
  /// The package has no web platform channel to initialize.
  static void registerWith(Object registrar) {}
}
