/// No-op Linux platform stub.
///
/// All haptic calls throw MissingPluginException and fall back to Flutter's
/// built-in HapticFeedback API (light/medium/heavy impact).
class RealPageFlipLinux {}
