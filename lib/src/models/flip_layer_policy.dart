import 'package:flutter/material.dart';

/// Strategy object that encapsulates 4-mode (single/double × forward/backward)
/// layer content allocation for the page flip compositing stack.
///
/// Extracted from [PageFlipLayerView]'s nested if/else to make each mode's
/// behavior independently testable and auditable.
///
/// ## Layer roles
///
/// | Layer | What it shows |
/// |-------|--------------|
/// | Bottom | Content revealed behind the fold |
/// | Middle | Stationary content under the flap |
/// | Flap | Shadow/highlight effect (not covered here) |
///
/// ## Modes
///
/// | Mode | Bottom | Middle |
/// |------|--------|--------|
/// | Single forward | Next page | Opaque paper |
/// | Single backward | Current page | Previous page |
/// | Double forward | Next spread right half | Current spread left half |
/// | Double backward | Previous spread right half | Current spread right half |
class FlipLayerPolicy {
  /// Whether the book is in double-spread mode (two pages per viewport).
  final bool isDoubleSpread;

  /// True when dragging forward (next page), false for backward (previous page).
  final bool isForward;

  /// The currently visible page/spread index.
  final int currentIndex;

  /// Total number of pages/spreads.
  final int itemCount;

  const FlipLayerPolicy({
    required this.isDoubleSpread,
    required this.isForward,
    required this.currentIndex,
    required this.itemCount,
  });

  // ─── Bottom layer (revealed behind the fold) ───

  /// Spread half to show in the bottom layer (double mode), or null.
  ///
  /// Null means the bottom layer should fall back to opaque paper
  /// (out-of-bounds or single mode).
  ({int index, Alignment alignment})? get bottomSpreadHalf {
    if (!isDoubleSpread) return null;
    if (isForward) {
      // Forward: reveal the NEXT spread's right half behind the fold
      if (currentIndex < itemCount - 1) {
        return (index: currentIndex + 1, alignment: Alignment.centerRight);
      }
      return null; // paper fallback on last spread
    }
    if (currentIndex > 0) {
      return (index: currentIndex - 1, alignment: Alignment.centerRight);
    }
    return null; // paper fallback
  }

  /// Full page/spread index for the bottom layer (single mode), or null for paper.
  int? get bottomPageIndex {
    if (isDoubleSpread) return null; // uses spread half instead
    if (isForward) {
      return currentIndex < itemCount - 1 ? currentIndex + 1 : null;
    }
    // Backward single: bottom shows the underside of the current page
    return currentIndex;
  }

  // ─── Middle layer (stationary under the flap) ───

  /// Full spread index for the middle layer (double mode), or null for single mode.
  ///
  /// In double mode the entire current spread sits stationary under the flap
  /// (half of it may be clipped by [PageFlipOpenClipper] in backward mode).
  int? get middleSpreadIndex => isDoubleSpread ? currentIndex : null;

  /// Page index for the middle layer (single backward mode), or null for paper.
  ///
  /// In single forward mode the middle layer is opaque paper (the current page
  /// rides in the flap layer). In single backward mode the previous page peels
  /// in from the left edge.
  int? get middlePageIndex {
    if (isDoubleSpread) return null; // uses full spread
    if (isForward) return null; // opaque paper
    return currentIndex > 0 ? currentIndex - 1 : null;
  }

  // ─── Flap front texture snapshot ───

  /// Spread index whose snapshot provides the flap-front texture, or null.
  ///
  /// In single forward mode the current page wraps onto the flap. In double
  /// mode the current spread provides the full-width texture.
  /// Null in single backward mode (no flap-front content needed).
  int? get flapSnapshotSpreadIndex {
    if (isDoubleSpread) return currentIndex;
    if (isForward) return currentIndex;
    return null;
  }
}
