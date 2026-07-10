import 'package:flutter/material.dart';
import 'package:real_page_flip/src/models/page_flip_effect_handler.dart';
import 'package:real_page_flip/src/models/paper_texture_preset.dart';
import 'package:real_page_flip/src/page_flip_widget.dart';

/// How [PageFlipWidget] maps pages to the viewport.
///
/// In [PageFlipSpreadMode.doubleSpread], each index is a two-page spread and
/// the host should supply full-spread page widgets plus matching spread
/// snapshots (same indices) for flap texture and spine-band reveal.
/// In [PageFlipSpreadMode.single], one page fills the viewport.
enum PageFlipSpreadMode {
  /// One page per viewport width.
  single,

  /// Left and right pages share one viewport (spine at center).
  doubleSpread,
}

/// Maps legacy `isDoubleSpread` flags to [PageFlipSpreadMode].
extension PageFlipSpreadModeCompat on PageFlipSpreadMode {
  /// Whether this mode uses a center spine and half-width page geometry.
  bool get isDoubleSpread => this == PageFlipSpreadMode.doubleSpread;

  /// Converts the historical boolean API to [PageFlipSpreadMode].
  static PageFlipSpreadMode fromIsDoubleSpread({
    required bool isDoubleSpread,
  }) =>
      isDoubleSpread
          ? PageFlipSpreadMode.doubleSpread
          : PageFlipSpreadMode.single;
}

/// Represents the performance tier of the device to adjust rendering quality.
enum DevicePerformanceProfile {
  /// Flagship devices: High resolution snapshots, dense meshes, full shadows.
  high,

  /// Mid-range devices: Moderate resolution, standard meshes, standard shadows.
  medium,

  /// Low-end devices (2020+ budget): Lower resolution snapshots, sparse meshes, simplified shadows, throttled haptics.
  low,
}

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
@immutable
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
    this.paperOpacity = 1.0,
    this.thinPaperStrength = 0.15,
    this.endRevealStrength = 0.0,
    this.flapContentFadeOutEnd = 0.20,
    this.flapContentRevealStart = 0.85,
    this.flapContentRevealEnd = 0.95,
    this.flapBackStrength = 0.0,
    this.doubleSpreadMidFoldBleed = 0.15,
    this.singlePageBackContentOpacity = 1.0,
    this.performanceProfile = DevicePerformanceProfile.medium,
    this.hapticTexturePreset = PaperTexturePreset.standard,
  });

  /// The performance profile to use for rendering quality.
  final DevicePerformanceProfile performanceProfile;

  /// The opacity of the page-flip flap (paper back side). Defaults to 1.0 (fully opaque).
  final double paperOpacity;

  /// How much the paper appears translucent like thin paper during flip (0.0–1.0).
  /// 0.0 = fully opaque, 0.15 = subtle thin-paper effect at mid-flip.
  ///
  /// At mid-flip (progress ~0.5) the paper is most transparent, letting the
  /// underlying page content show through slightly — like real thin paper.
  final double thinPaperStrength;

  /// How much the next page content shows through the paper at end of flip (0.0–1.0).
  /// Defaults to 0.0 (no transparent reveal, since late-settle texture cross-fade handles it).
  final double endRevealStrength;

  /// Flip progress (0–1) by which flap-front content is fully hidden during fold.
  ///
  /// Text fades out quickly between progress 0 and this value so bent flap
  /// shows paper back only during the main peel.
  final double flapContentFadeOutEnd;

  /// Flip progress (0–1) before late settle content begins fading in.
  ///
  /// Keeps the flap blank (paper back) from [flapContentFadeOutEnd] until here.
  final double flapContentRevealStart;

  /// Flip progress (0–1) at which flap-front content reaches full opacity.
  final double flapContentRevealEnd;

  /// Retained for source compatibility. No-op since double-spread rendering
  /// maps the real verso directly instead of drawing a mirrored ghost mesh.
  final double flapBackStrength;

  /// Retained for source compatibility. No-op since the real verso stays fully
  /// visible throughout a double-spread turn.
  final double doubleSpreadMidFoldBleed;

  /// Single-page only: opacity of the flipping page's own content while it is
  /// the back-facing side mid-flip (0.0–1.0).
  ///
  /// In single-page mode each page is single-sided, so the engine keeps the
  /// flipping page's content visible across the fold only on the high-fidelity
  /// profile. Medium/low profiles render the back-facing flap as blank paper
  /// through the main fold for lower GPU cost and to avoid reverse-text
  /// exposure.
  ///
  /// On the high profile, lowering this dims the peeled content toward the
  /// paper colour during the peel (but NOT during the late settle reveal of the
  /// destination page), simulating thin Bible (India) paper where the reverse
  /// text bleeds through only faintly — as if a sheet of paper were laid over
  /// the back. A value around `0.35` gives a subtle "thin paper" bleed-through.
  ///
  /// Has no effect in double-spread mode (see [flapBackStrength]).
  final double singlePageBackContentOpacity;

  /// Whether to enable haptic feedback.
  final bool enableHaptics;

  /// Whether to enable sound effects.
  final bool enableSound;

  /// Paper texture preset for haptic feedback feel.
  ///
  /// Controls vibration intensity, trigger sensitivity, duration, and tick
  /// density. Defaults to [PaperTexturePreset.standard].
  final PaperTexturePreset hapticTexturePreset;

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

  /// Creates a copy of this [PageFlipConfig] with the given fields replaced.
  PageFlipConfig copyWith({
    Duration? duration,
    double? cutoffForward,
    double? cutoffPrevious,
    Color? backgroundColor,
    bool? isRightSwipe,
    bool? enableSwipe,
    double? sensitivity,
    double? edgeTapWidthRatio,
    bool? skipTapAnimation,
    String Function(int index, int total)? semanticBuilder,
    String? edgeTapPreviousLabel,
    String? edgeTapNextLabel,
    String? edgeTapPreviousHint,
    String? edgeTapNextHint,
    bool? enableHaptics,
    bool? enableSound,
    PageFlipEffectHandler? effectHandler,
    double? paperOpacity,
    double? thinPaperStrength,
    double? endRevealStrength,
    double? flapContentFadeOutEnd,
    double? flapContentRevealStart,
    double? flapContentRevealEnd,
    double? flapBackStrength,
    double? doubleSpreadMidFoldBleed,
    double? singlePageBackContentOpacity,
    DevicePerformanceProfile? performanceProfile,
    PaperTexturePreset? hapticTexturePreset,
    bool clearSemanticBuilder = false,
    bool clearBackgroundColor = false,
    bool clearEffectHandler = false,
  }) =>
      PageFlipConfig(
        duration: duration ?? this.duration,
        cutoffForward: cutoffForward ?? this.cutoffForward,
        cutoffPrevious: cutoffPrevious ?? this.cutoffPrevious,
        backgroundColor: clearBackgroundColor
            ? null
            : (backgroundColor ?? this.backgroundColor),
        isRightSwipe: isRightSwipe ?? this.isRightSwipe,
        enableSwipe: enableSwipe ?? this.enableSwipe,
        sensitivity: sensitivity ?? this.sensitivity,
        edgeTapWidthRatio: edgeTapWidthRatio ?? this.edgeTapWidthRatio,
        skipTapAnimation: skipTapAnimation ?? this.skipTapAnimation,
        semanticBuilder: clearSemanticBuilder
            ? null
            : (semanticBuilder ?? this.semanticBuilder),
        edgeTapPreviousLabel: edgeTapPreviousLabel ?? this.edgeTapPreviousLabel,
        edgeTapNextLabel: edgeTapNextLabel ?? this.edgeTapNextLabel,
        edgeTapPreviousHint: edgeTapPreviousHint ?? this.edgeTapPreviousHint,
        edgeTapNextHint: edgeTapNextHint ?? this.edgeTapNextHint,
        enableHaptics: enableHaptics ?? this.enableHaptics,
        enableSound: enableSound ?? this.enableSound,
        effectHandler:
            clearEffectHandler ? null : (effectHandler ?? this.effectHandler),
        paperOpacity: paperOpacity ?? this.paperOpacity,
        thinPaperStrength: thinPaperStrength ?? this.thinPaperStrength,
        endRevealStrength: endRevealStrength ?? this.endRevealStrength,
        flapContentFadeOutEnd:
            flapContentFadeOutEnd ?? this.flapContentFadeOutEnd,
        flapContentRevealStart:
            flapContentRevealStart ?? this.flapContentRevealStart,
        flapContentRevealEnd: flapContentRevealEnd ?? this.flapContentRevealEnd,
        flapBackStrength: flapBackStrength ?? this.flapBackStrength,
        doubleSpreadMidFoldBleed:
            doubleSpreadMidFoldBleed ?? this.doubleSpreadMidFoldBleed,
        singlePageBackContentOpacity:
            singlePageBackContentOpacity ?? this.singlePageBackContentOpacity,
        performanceProfile: performanceProfile ?? this.performanceProfile,
        hapticTexturePreset: hapticTexturePreset ?? this.hapticTexturePreset,
      );

  /// Runtime-safe view of this configuration.
  ///
  /// The public constructor stays permissive and const-friendly, but the engine
  /// must not let NaN, infinity, negative durations, or out-of-range opacity and
  /// gesture values enter animation and rendering math. Host apps still retain
  /// their original config object; widgets use this normalized copy internally.
  PageFlipConfig get normalized {
    var safeFadeOutEnd = _safeUnitInterval(
      flapContentFadeOutEnd,
      defaultSettings.flapContentFadeOutEnd,
    );
    final safeRevealStart = _safeUnitInterval(
      flapContentRevealStart,
      defaultSettings.flapContentRevealStart,
    );
    var safeRevealEnd = _safeUnitInterval(
      flapContentRevealEnd,
      defaultSettings.flapContentRevealEnd,
    );

    safeFadeOutEnd = safeFadeOutEnd.clamp(0.0, safeRevealStart).toDouble();
    if (safeRevealEnd < safeRevealStart) {
      safeRevealEnd = safeRevealStart;
    }

    final normalizedConfig = PageFlipConfig(
      duration: _safeDuration(duration),
      cutoffForward: _safeUnitInterval(
        cutoffForward,
        defaultSettings.cutoffForward,
      ),
      cutoffPrevious: _safeUnitInterval(
        cutoffPrevious,
        defaultSettings.cutoffPrevious,
      ),
      backgroundColor: backgroundColor,
      isRightSwipe: isRightSwipe,
      enableSwipe: enableSwipe,
      sensitivity: _safeUnitInterval(
        sensitivity,
        defaultSettings.sensitivity,
      ),
      edgeTapWidthRatio: _safeRange(
        edgeTapWidthRatio,
        0,
        0.5,
        defaultSettings.edgeTapWidthRatio,
      ),
      skipTapAnimation: skipTapAnimation,
      semanticBuilder: semanticBuilder,
      edgeTapPreviousLabel: edgeTapPreviousLabel,
      edgeTapNextLabel: edgeTapNextLabel,
      edgeTapPreviousHint: edgeTapPreviousHint,
      edgeTapNextHint: edgeTapNextHint,
      enableHaptics: enableHaptics,
      enableSound: enableSound,
      effectHandler: effectHandler,
      paperOpacity: _safeUnitInterval(
        paperOpacity,
        defaultSettings.paperOpacity,
      ),
      thinPaperStrength: _safeUnitInterval(
        thinPaperStrength,
        defaultSettings.thinPaperStrength,
      ),
      endRevealStrength: _safeUnitInterval(
        endRevealStrength,
        defaultSettings.endRevealStrength,
      ),
      flapContentFadeOutEnd: safeFadeOutEnd,
      flapContentRevealStart: safeRevealStart,
      flapContentRevealEnd: safeRevealEnd,
      flapBackStrength: _safeUnitInterval(
        flapBackStrength,
        defaultSettings.flapBackStrength,
      ),
      doubleSpreadMidFoldBleed: _safeUnitInterval(
        doubleSpreadMidFoldBleed,
        defaultSettings.doubleSpreadMidFoldBleed,
      ),
      singlePageBackContentOpacity: _safeUnitInterval(
        singlePageBackContentOpacity,
        defaultSettings.singlePageBackContentOpacity,
      ),
      performanceProfile: performanceProfile,
      hapticTexturePreset: hapticTexturePreset,
    );

    return normalizedConfig == this ? this : normalizedConfig;
  }

  static const Duration _maxAnimationDuration = Duration(seconds: 10);

  static Duration _safeDuration(Duration value) {
    if (value.inMicroseconds <= 0) return defaultSettings.duration;
    if (value > _maxAnimationDuration) return _maxAnimationDuration;
    return value;
  }

  static double _safeUnitInterval(double value, double fallback) =>
      _safeRange(value, 0, 1, fallback);

  static double _safeRange(
    double value,
    double min,
    double max,
    double fallback,
  ) {
    final safeValue = value.isFinite ? value : fallback;
    return safeValue.clamp(min, max).toDouble();
  }

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
          semanticBuilder == other.semanticBuilder &&
          enableHaptics == other.enableHaptics &&
          enableSound == other.enableSound &&
          hapticTexturePreset == other.hapticTexturePreset &&
          effectHandler == other.effectHandler &&
          paperOpacity == other.paperOpacity &&
          thinPaperStrength == other.thinPaperStrength &&
          endRevealStrength == other.endRevealStrength &&
          flapContentFadeOutEnd == other.flapContentFadeOutEnd &&
          flapContentRevealStart == other.flapContentRevealStart &&
          flapContentRevealEnd == other.flapContentRevealEnd &&
          flapBackStrength == other.flapBackStrength &&
          doubleSpreadMidFoldBleed == other.doubleSpreadMidFoldBleed &&
          singlePageBackContentOpacity == other.singlePageBackContentOpacity &&
          performanceProfile == other.performanceProfile &&
          edgeTapPreviousLabel == other.edgeTapPreviousLabel &&
          edgeTapNextLabel == other.edgeTapNextLabel &&
          edgeTapPreviousHint == other.edgeTapPreviousHint &&
          edgeTapNextHint == other.edgeTapNextHint;

  @override
  int get hashCode => Object.hashAll([
        duration,
        cutoffForward,
        cutoffPrevious,
        backgroundColor,
        isRightSwipe,
        enableSwipe,
        sensitivity,
        edgeTapWidthRatio,
        skipTapAnimation,
        semanticBuilder,
        enableHaptics,
        enableSound,
        hapticTexturePreset,
        effectHandler,
        paperOpacity,
        thinPaperStrength,
        endRevealStrength,
        flapContentFadeOutEnd,
        flapContentRevealStart,
        flapContentRevealEnd,
        flapBackStrength,
        doubleSpreadMidFoldBleed,
        singlePageBackContentOpacity,
        performanceProfile,
        edgeTapPreviousLabel,
        edgeTapNextLabel,
        edgeTapPreviousHint,
        edgeTapNextHint,
      ]);
}
