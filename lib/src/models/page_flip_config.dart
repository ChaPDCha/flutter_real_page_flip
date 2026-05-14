import 'package:flutter/material.dart';
import 'page_flip_effect_handler.dart';

/// Configuration for PageFlipWidget behavior and styling.
///
/// ## Dark Mode Support
///
/// The engine automatically adapts to the current Flutter theme.
/// When [backgroundColor] is `null` (the default), the flipping page back
/// uses `Theme.of(context).scaffoldBackgroundColor`, so setting
/// `MaterialApp.darkTheme` is all that is needed:
///
/// ```dart
/// // Automatic dark mode — no extra config needed
/// PageFlipWidget(
///   itemCount: pages.length,
///   itemBuilder: (context, index) => MyPage(index),
/// )
/// ```
///
/// To pin the paper back to a specific color (e.g. a custom dark shade),
/// pass an explicit [backgroundColor]:
///
/// ```dart
/// // Custom dark paper color
/// PageFlipWidget(
///   config: PageFlipConfig(
///     backgroundColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFEEEEEE),
///   ),
///   ...
/// )
/// ```
class PageFlipConfig {
  /// Creates a [PageFlipConfig] with the given settings.
  const PageFlipConfig({
    this.duration = const Duration(milliseconds: 450),
    this.cutoffForward = 0.4,
    this.cutoffPrevious = 0.4,
    this.backgroundColor,
    this.isRightSwipe = false,
    this.enableSwipe = true,
    this.sensitivity = 0.5,
    this.edgeTapWidthRatio = 0.1,
    this.skipTapAnimation = true,
    this.semanticBuilder,
    this.edgeTapPreviousLabel,
    this.edgeTapNextLabel,
    this.edgeTapPreviousHint,
    this.edgeTapNextHint,
    this.enableHaptics = true,
    this.enableSound = true,
    this.effectHandler,
  });

  /// Whether to enable haptic feedback.
  final bool enableHaptics;

  /// Whether to enable sound effects.
  final bool enableSound;

  /// Custom handler for effects. If null, a default implementation is used.
  final PageFlipEffectHandler? effectHandler;

  /// Duration of the flip animation.
  final Duration duration;

  /// Drag progress threshold (0.0 to 1.0, default 0.4) for a successful forward flip.
  ///
  /// When the user releases a forward drag beyond this progress, the flip
  /// completes; otherwise the page snaps back. Higher values require dragging
  /// further across the page.
  final double cutoffForward;

  /// Drag progress threshold (0.0 to 1.0, default 0.4) for a successful backward flip.
  ///
  /// When the user releases a backward drag beyond this progress, the flip
  /// completes; otherwise the page snaps back. Higher values require dragging
  /// further across the page.
  final double cutoffPrevious;

  /// Background color of the page-flip flap (the paper back side).
  ///
  /// When `null` (default), the engine reads
  /// `Theme.of(context).scaffoldBackgroundColor` at render time, which
  /// means **dark mode works automatically** when the host app has a dark
  /// [ThemeData] applied.
  ///
  /// The shadow intensity is also adjusted automatically:
  /// darker backgrounds receive softer shadows so the flip stays natural
  /// in both light and dark environments.
  final Color? backgroundColor;

  /// Whether the swipe direction is right-to-left.
  final bool isRightSwipe;

  /// Whether to enable swipe gestures.
  final bool enableSwipe;

  /// Sensitivity of the drag gesture (0.0 to 1.0).
  final double sensitivity;

  /// Width ratio of the edge tap area (0.0 to 0.5).
  final double edgeTapWidthRatio;

  /// Whether to skip animation on tap (instant flip).
  final bool skipTapAnimation;

  /// Builder for semantic labels (i18n support).
  final String Function(int index, int total)? semanticBuilder;

  /// Semantics label for left edge tap (previous page). When null, default used.
  final String? edgeTapPreviousLabel;

  /// Semantics label for right edge tap (next page). When null, default used.
  final String? edgeTapNextLabel;

  /// Semantics hint for left edge tap.
  final String? edgeTapPreviousHint;

  /// Semantics hint for right edge tap.
  final String? edgeTapNextHint;

  /// Default configuration.
  static const PageFlipConfig defaultSettings = PageFlipConfig();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PageFlipConfig &&
          runtimeType == other.runtimeType &&
          duration == other.duration &&
          cutoffForward == other.cutoffForward &&
          cutoffPrevious == other.cutoffPrevious &&
          backgroundColor == other.backgroundColor &&
          isRightSwipe == other.isRightSwipe &&
          enableSwipe == other.enableSwipe &&
          sensitivity == other.sensitivity &&
          edgeTapWidthRatio == other.edgeTapWidthRatio &&
          skipTapAnimation == other.skipTapAnimation &&
          enableHaptics == other.enableHaptics &&
          enableSound == other.enableSound &&
          effectHandler == other.effectHandler &&
          edgeTapPreviousLabel == other.edgeTapPreviousLabel &&
          edgeTapNextLabel == other.edgeTapNextLabel &&
          edgeTapPreviousHint == other.edgeTapPreviousHint &&
          edgeTapNextHint == other.edgeTapNextHint;

  @override
  int get hashCode =>
      duration.hashCode ^
      cutoffForward.hashCode ^
      cutoffPrevious.hashCode ^
      backgroundColor.hashCode ^
      isRightSwipe.hashCode ^
      enableSwipe.hashCode ^
      sensitivity.hashCode ^
      edgeTapWidthRatio.hashCode ^
      skipTapAnimation.hashCode ^
      enableHaptics.hashCode ^
      enableSound.hashCode ^
      effectHandler.hashCode ^
      edgeTapPreviousLabel.hashCode ^
      edgeTapNextLabel.hashCode ^
      edgeTapPreviousHint.hashCode ^
      edgeTapNextHint.hashCode;
}
