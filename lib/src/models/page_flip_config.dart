import 'package:flutter/material.dart';
import 'page_flip_effect_handler.dart';

/// Configuration for PageFlipWidget behavior and styling.
class PageFlipConfig {
  /// Creates a configuration profile to customize the behavior and styling of [PageFlipWidget].
  const PageFlipConfig({
    this.duration = const Duration(milliseconds: 450),
    this.cutoffForward = 0.8,
    this.cutoffPrevious = 0.1,
    this.maxDragDistance,
    this.backgroundColor = Colors.white,
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

  /// Cutoff point for forward flip (0.0 to 1.0).
  /// Reserved for future per-direction threshold; drag success currently uses
  /// a fixed threshold in [PageFlipStateController].
  final double cutoffForward;

  /// Cutoff point for previous flip (0.0 to 1.0).
  /// Reserved for future per-direction threshold; see [cutoffForward].
  final double cutoffPrevious;

  /// The maximum physical logical pixels required to complete a full page swipe.
  /// If null, defaults to the full width of the widget.
  /// Setting this improves ergonomics on very wide screens (e.g. tablets).
  final double? maxDragDistance;

  /// Background color of the page.
  final Color backgroundColor;

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
          maxDragDistance == other.maxDragDistance &&
          backgroundColor == other.backgroundColor &&
          isRightSwipe == other.isRightSwipe &&
          enableSwipe == other.enableSwipe &&
          sensitivity == other.sensitivity &&
          edgeTapWidthRatio == other.edgeTapWidthRatio &&
          skipTapAnimation == other.skipTapAnimation &&
          edgeTapPreviousLabel == other.edgeTapPreviousLabel &&
          edgeTapNextLabel == other.edgeTapNextLabel &&
          edgeTapPreviousHint == other.edgeTapPreviousHint &&
          edgeTapNextHint == other.edgeTapNextHint;

  @override
  int get hashCode =>
      duration.hashCode ^
      cutoffForward.hashCode ^
      cutoffPrevious.hashCode ^
      maxDragDistance.hashCode ^
      backgroundColor.hashCode ^
      isRightSwipe.hashCode ^
      enableSwipe.hashCode ^
      sensitivity.hashCode ^
      edgeTapWidthRatio.hashCode ^
      skipTapAnimation.hashCode ^
      edgeTapPreviousLabel.hashCode ^
      edgeTapNextLabel.hashCode ^
      edgeTapPreviousHint.hashCode ^
      edgeTapNextHint.hashCode;
}
