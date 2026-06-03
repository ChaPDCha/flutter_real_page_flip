import 'package:flutter/material.dart';
import 'package:real_page_flip/src/effects/page_flip_engine.dart';
import 'package:real_page_flip/src/models/flip_layer_policy.dart';

/// Builds one half of a spread snapshot for spine-band reveal (from [FlipLayerPolicy]).
typedef FlipSpreadHalfBuilder = Widget Function(
  int spreadIndex,
  Alignment alignment,
);

/// Layer 2: stationary spread half, spine reveal band, and fold clip stack.
///
/// [FlipLayerPolicy] remains the source of spread/page indices; this widget only
/// composes clips and children from [policy] and [spreadHalfBuilder].
class FlipMiddleLayerStack extends StatelessWidget {
  /// Creates the middle flip layer (clip + stationary half + spine reveal).
  const FlipMiddleLayerStack({
    required this.middleLayerContent,
    required this.geo,
    required this.policy,
    required this.floatProgress,
    required this.isDoubleSpread,
    required this.isForward,
    required this.touchPosition,
    required this.spreadHalfBuilder,
    super.key,
  });

  /// Stationary middle content (full spread or single page).
  final Widget middleLayerContent;

  /// Fold geometry for clippers.
  final PageFlipGeometry geo;

  /// Layer indices from drag direction and spread mode.
  final FlipLayerPolicy policy;

  /// Normalised fold progress (0–1).
  final double floatProgress;

  /// Dual-spread (2단) layout when true.
  final bool isDoubleSpread;

  /// Forward page turn when true.
  final bool isForward;

  /// Touch position for clip paths.
  final Offset touchPosition;

  /// Builds spread-half widgets for spine reveal (snapshots or underlay).
  final FlipSpreadHalfBuilder spreadHalfBuilder;

  @override
  Widget build(BuildContext context) {
    final stack = _buildStack(context);

    if (isDoubleSpread && !isForward) {
      return stack;
    }

    return ClipPath(
      clipper: PageFlipClipper(
        progress: floatProgress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: isDoubleSpread,
        isForward: isForward,
        geo: geo,
      ),
      child: stack,
    );
  }

  Widget _buildStack(BuildContext context) {
    if (!isDoubleSpread) {
      return middleLayerContent;
    }

    final spineReveal = _buildSpineRevealBand(context);
    final stationaryHalf = _buildStationarySpreadHalf(middleLayerContent);

    if (!isForward) {
      final stationaryClipper = PageFlipOpenClipper(
        progress: geo.progress,
        isRightToLeft: true,
        touchOffset: touchPosition,
        isDoubleSpread: true,
        isForward: false,
        geo: geo,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (spineReveal != null) spineReveal,
          ClipPath(
            clipper: stationaryClipper,
            child: stationaryHalf,
          ),
        ],
      );
    }

    if (spineReveal == null) {
      return stationaryHalf;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        stationaryHalf,
        spineReveal,
      ],
    );
  }

  Widget _buildStationarySpreadHalf(Widget spreadContent) {
    return clipFullSpreadHalf(
      alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
      child: spreadContent,
    );
  }

  Widget? _buildSpineRevealBand(BuildContext context) {
    if (buildDoubleSpreadSpineRevealPath(geo) == null) return null;
    final spreadIndex = policy.spineRevealSpreadIndex;
    if (spreadIndex == null) return null;
    return ClipPath(
      clipper: PageFlipSpineRevealClipper(geo: geo),
      child: spreadHalfBuilder(spreadIndex, Alignment.centerLeft),
    );
  }
}
